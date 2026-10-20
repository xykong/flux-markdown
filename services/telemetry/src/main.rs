mod counters;
use axum::{
    extract::{DefaultBodyLimit, State},
    http::StatusCode,
    routing::{get, post},
    Json, Router,
};
use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use std::{
    path::PathBuf,
    sync::{Arc, Mutex},
    time::{SystemTime, UNIX_EPOCH},
};

#[derive(Deserialize, Serialize, Clone, Debug)]
#[serde(deny_unknown_fields)]
struct Event {
    schema_version: u32,
    installation_id: String,
    event_id: String,
    session_id: String,
    app_version: String,
    os_version: String,
    architecture: String,
    channel: String,
    source: String,
    event_type: String,
    timestamp: String,
    active_seconds: u32,
    documents_viewed: u32,
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Batch {
    events: Vec<Event>,
}
fn now() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs() as i64
}
fn valid_version(s: &str) -> bool {
    let parts: Vec<_> = s.split('.').collect();
    (2..=3).contains(&parts.len())
        && parts
            .iter()
            .all(|p| !p.is_empty() && p.len() <= 9 && p.bytes().all(|b| b.is_ascii_digit()))
}
fn valid(e: &Event) -> bool {
    let timestamp = chrono::DateTime::parse_from_rfc3339(&e.timestamp)
        .map(|v| v.timestamp())
        .unwrap_or(0);
    e.schema_version == 1
        && [&e.installation_id, &e.event_id, &e.session_id]
            .iter()
            .all(|s| {
                uuid::Uuid::parse_str(s)
                    .map(|id| id.to_string() == **s)
                    .unwrap_or(false)
            })
        && valid_version(&e.app_version)
        && valid_version(&e.os_version)
        && ["arm64", "x86_64"].contains(&e.architecture.as_str())
        && ["dmg", "homebrew", "macports", "unknown"].contains(&e.channel.as_str())
        && ["app", "quicklook"].contains(&e.source.as_str())
        && ["session_summary", "session_checkpoint"].contains(&e.event_type.as_str())
        && e.active_seconds <= 86400
        && e.documents_viewed <= 10000
        && timestamp >= now() - 7 * 86400
        && timestamp <= now() + 300
}
fn open(path: &PathBuf) -> rusqlite::Result<Connection> {
    let db = Connection::open(path)?;
    db.busy_timeout(std::time::Duration::from_secs(3))?;
    db.execute_batch("PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA max_page_count=1048576;
        CREATE TABLE IF NOT EXISTS events(event_id TEXT PRIMARY KEY, received_at INTEGER NOT NULL, payload TEXT NOT NULL);
        CREATE INDEX IF NOT EXISTS events_received ON events(received_at);")?;
    counters::schema(&db)?;
    Ok(db)
}
fn insert(db: &mut Connection, events: &[Event]) -> Result<(), StatusCode> {
    if events.is_empty() || events.len() > 50 || !events.iter().all(valid) {
        return Err(StatusCode::BAD_REQUEST);
    }
    let tx = db
        .transaction()
        .map_err(|_| StatusCode::SERVICE_UNAVAILABLE)?;
    for e in events {
        let payload = serde_json::to_string(e).map_err(|_| StatusCode::BAD_REQUEST)?;
        let previous: Option<String> = tx
            .query_row(
                "SELECT payload FROM events WHERE event_id=?1",
                [&e.event_id],
                |r| r.get(0),
            )
            .map(Some)
            .or_else(|e| {
                if matches!(e, rusqlite::Error::QueryReturnedNoRows) {
                    Ok(None)
                } else {
                    Err(e)
                }
            })
            .map_err(|_| StatusCode::SERVICE_UNAVAILABLE)?;
        if previous.is_some_and(|v| v != payload) {
            return Err(StatusCode::CONFLICT);
        }
        tx.execute(
            "INSERT OR IGNORE INTO events VALUES (?1,?2,?3)",
            params![e.event_id, now(), payload],
        )
        .map_err(|_| StatusCode::SERVICE_UNAVAILABLE)?;
    }
    tx.commit().map_err(|_| StatusCode::SERVICE_UNAVAILABLE)
}
type Db = Arc<Mutex<Connection>>;
async fn ingest(
    State(db): State<Db>,
    Json(batch): Json<Batch>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    let ids: Vec<_> = batch.events.iter().map(|e| e.event_id.clone()).collect();
    tokio::task::spawn_blocking(move || {
        let mut db = db.lock().map_err(|_| StatusCode::SERVICE_UNAVAILABLE)?;
        insert(&mut db, &batch.events)
    })
    .await
    .map_err(|_| StatusCode::SERVICE_UNAVAILABLE)??;
    Ok(Json(serde_json::json!({"accepted_event_ids":ids})))
}
#[tokio::main(flavor = "current_thread")]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let path = PathBuf::from(std::env::var("TELEMETRY_DB")?);
    let db = open(&path)?;
    match std::env::args().nth(1).as_deref() {
        Some("delete-installation") => {
            let id = std::env::args()
                .nth(2)
                .ok_or("installation UUID required")?;
            if uuid::Uuid::parse_str(&id)?.to_string() != id {
                return Err("invalid UUID".into());
            }
            let tx = db.unchecked_transaction()?;
            tx.execute("DELETE FROM snapshots WHERE installation=?1", [&id])?;
            tx.execute("DELETE FROM counters WHERE installation=?1", [&id])?;
            tx.execute(
                "DELETE FROM timezone_observations WHERE installation=?1",
                [&id],
            )?;
            tx.execute(
                "DELETE FROM events WHERE json_extract(payload,'$.installation_id')=?1",
                [&id],
            )?;
            tx.commit()?;
            println!("Deleted records for supplied installation");
        }
        Some("prune") => {
            db.execute(
                "DELETE FROM events WHERE received_at < ?1",
                [now() - 180 * 86400],
            )?;
            db.execute(
                "DELETE FROM snapshots WHERE received_at < ?1",
                [now() - 180 * 86400],
            )?;
            db.execute(
                "DELETE FROM counters WHERE day < ?1",
                [(chrono::Utc::now().date_naive() - chrono::Duration::days(180)).to_string()],
            )?;
            db.execute(
                "DELETE FROM timezone_observations WHERE received_at < ?1",
                [now() - 180 * 86400],
            )?;
            db.execute_batch("PRAGMA wal_checkpoint(TRUNCATE);")?;
        }
        Some("timezones") => {
            let start: i64 = std::env::args()
                .nth(2)
                .ok_or("start Unix seconds required")?
                .parse()?;
            let end: i64 = std::env::args()
                .nth(3)
                .ok_or("end Unix seconds required")?
                .parse()?;
            if start < 0 || end <= start {
                return Err("expected 0 <= start < end".into());
            }
            println!(
                "{}",
                serde_json::to_string_pretty(&counters::timezone_summary(&db, start, end)?)?
            );
        }
        Some("daily") => {
            println!(
                "{}",
                serde_json::to_string_pretty(&counters::summary(&db)?)?
            );
        }
        Some("summary") => {
            let mut query = db.prepare("SELECT json_extract(payload,'$.os_version'),count(DISTINCT json_extract(payload,'$.installation_id')),sum(json_extract(payload,'$.active_seconds')),sum(json_extract(payload,'$.documents_viewed')),count(*) FROM events GROUP BY 1")?;
            let rows = query.query_map([], |r| Ok(serde_json::json!({"os_version":r.get::<_,String>(0)?,"installations":r.get::<_,i64>(1)?,"active_seconds":r.get::<_,i64>(2)?,"documents_viewed":r.get::<_,i64>(3)?,"events":r.get::<_,i64>(4)?})))?.collect::<rusqlite::Result<Vec<_>>>()?;
            println!("{}", serde_json::to_string_pretty(&rows)?);
        }
        None => {
            let app = Router::new()
                .route("/healthz", get(|| async { "ok" }))
                .route("/v1/events", post(ingest))
                .route("/v2/snapshots", post(counters::ingest))
                .route("/v3/snapshots", post(counters::ingest_timestamps))
                .layer(DefaultBodyLimit::max(65536))
                .with_state(Arc::new(Mutex::new(db)));
            let listener = tokio::net::TcpListener::bind("127.0.0.1:8765").await?;
            axum::serve(listener, app).await?;
        }
        _ => return Err("unknown command".into()),
    }
    Ok(())
}
#[cfg(test)]
mod tests {
    use super::*;
    fn event() -> Event {
        serde_json::from_value(serde_json::json!({
        "schema_version":1,"installation_id":"00000000-0000-4000-8000-000000000001",
        "event_id":"00000000-0000-4000-8000-000000000002","session_id":"00000000-0000-4000-8000-000000000003",
        "app_version":"1.37.596","os_version":"11.7.10","architecture":"x86_64","channel":"unknown",
        "source":"app","event_type":"session_summary","timestamp":chrono::Utc::now().to_rfc3339(),
        "active_seconds":30,"documents_viewed":2})).unwrap()
    }
    #[test]
    fn limits_and_expired_events() {
        let mut db = open(&PathBuf::from(":memory:")).unwrap();
        assert_eq!(insert(&mut db, &[]), Err(StatusCode::BAD_REQUEST));
        assert_eq!(
            insert(&mut db, &vec![event(); 51]),
            Err(StatusCode::BAD_REQUEST)
        );
        let mut e = event();
        e.timestamp = "2000-01-01T00:00:00Z".into();
        assert!(!valid(&e));
        e = event();
        e.installation_id = "a-person".into();
        assert!(!valid(&e));
        e = event();
        e.os_version = "private text".into();
        assert!(!valid(&e));
    }
    #[test]
    fn retry_and_conflict() {
        let mut db = open(&PathBuf::from(":memory:")).unwrap();
        let e = event();
        insert(&mut db, &[e.clone()]).unwrap();
        insert(&mut db, &[e.clone()]).unwrap();
        let mut conflicting = e;
        conflicting.documents_viewed = 3;
        assert_eq!(insert(&mut db, &[conflicting]), Err(StatusCode::CONFLICT));
        assert_eq!(
            db.query_row("SELECT count(*) FROM events", [], |r| r.get::<_, i64>(0))
                .unwrap(),
            1
        );
    }
    #[test]
    fn private_fields_and_invalid_types() {
        let mut e = serde_json::to_value(event()).unwrap();
        e["path"] = "secret".into();
        assert!(serde_json::from_value::<Event>(e).is_err());
        let mut e = serde_json::to_value(event()).unwrap();
        e["documents_viewed"] = true.into();
        assert!(serde_json::from_value::<Event>(e).is_err());
    }
    #[test]
    fn validation_is_atomic() {
        let mut db = open(&PathBuf::from(":memory:")).unwrap();
        let e = event();
        let mut bad = e.clone();
        bad.active_seconds = 999999;
        assert_eq!(insert(&mut db, &[e, bad]), Err(StatusCode::BAD_REQUEST));
        assert_eq!(
            db.query_row("SELECT count(*) FROM events", [], |r| r.get::<_, i64>(0))
                .unwrap(),
            0
        );
    }
}
