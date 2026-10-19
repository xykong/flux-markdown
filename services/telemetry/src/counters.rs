use super::*;
#[derive(Deserialize, Serialize, Clone)]
#[serde(deny_unknown_fields)]
pub struct Snapshot {
    bucket_id: String,
    day: String,
    app_version: String,
    os_version: String,
    source: String,
    sequence: i64,
    active_seconds: i64,
    documents_viewed: i64,
}
#[derive(Deserialize, Serialize, Clone)]
#[serde(deny_unknown_fields)]
pub struct Upload {
    schema_version: u32,
    installation_id: String,
    architecture: String,
    channel: String,
    snapshots: Vec<Snapshot>,
}
pub fn schema(db: &Connection) -> rusqlite::Result<()> {
    db.execute_batch(
        "CREATE TABLE IF NOT EXISTS snapshots (
      installation TEXT NOT NULL,bucket TEXT NOT NULL,sequence INTEGER NOT NULL,
      received_at INTEGER NOT NULL,payload TEXT NOT NULL,
      PRIMARY KEY(installation,bucket,sequence));
      CREATE INDEX IF NOT EXISTS snapshots_received ON snapshots(received_at);
      CREATE TABLE IF NOT EXISTS counters (
      installation TEXT NOT NULL,bucket TEXT NOT NULL,day TEXT NOT NULL,
      app_version TEXT NOT NULL,os_version TEXT NOT NULL,source TEXT NOT NULL,
      sequence INTEGER NOT NULL,seconds INTEGER NOT NULL,views INTEGER NOT NULL,
      PRIMARY KEY(installation,bucket));",
    )
}
fn uuid_ok(s: &str) -> bool {
    uuid::Uuid::parse_str(s)
        .map(|v| v.to_string() == s)
        .unwrap_or(false)
}
pub fn store(db: &mut Connection, upload: &Upload) -> Result<serde_json::Value, StatusCode> {
    let invalid = StatusCode::BAD_REQUEST;
    let unavailable = StatusCode::SERVICE_UNAVAILABLE;
    if upload.schema_version != 2
        || !uuid_ok(&upload.installation_id)
        || upload.snapshots.is_empty()
        || upload.snapshots.len() > 50
        || !["arm64", "x86_64"].contains(&upload.architecture.as_str())
        || !["dmg", "homebrew", "macports", "unknown"].contains(&upload.channel.as_str())
    {
        return Err(invalid);
    }
    let today = chrono::Utc::now().date_naive();
    let tx = db.transaction().map_err(|_| unavailable)?;
    let mut ack = serde_json::Map::new();
    for s in &upload.snapshots {
        let day = chrono::NaiveDate::parse_from_str(&s.day, "%Y-%m-%d").map_err(|_| invalid)?;
        if s.day != day.format("%Y-%m-%d").to_string()
            || day > today
            || day < today - chrono::Duration::days(90)
            || !uuid_ok(&s.bucket_id)
            || !valid_version(&s.app_version)
            || !valid_version(&s.os_version)
            || !["app", "quicklook"].contains(&s.source.as_str())
            || s.sequence < 1
            || s.sequence > 10000000
            || !(0..=86400).contains(&s.active_seconds)
            || !(0..=100000).contains(&s.documents_viewed)
        {
            return Err(invalid);
        }
        // Snapshot payload is canonical and includes environment. No client data appears in logs.
        let payload=serde_json::to_string(&serde_json::json!({"snapshot":s,"architecture":upload.architecture,"channel":upload.channel})).map_err(|_|invalid)?;
        let previous: Option<String> = tx
            .query_row(
                "SELECT payload FROM snapshots WHERE installation=?1 AND bucket=?2 AND sequence=?3",
                params![upload.installation_id, s.bucket_id, s.sequence],
                |r| r.get(0),
            )
            .optional()
            .map_err(|_| unavailable)?;
        if previous.as_ref().is_some_and(|p| p != &payload) {
            return Err(StatusCode::CONFLICT);
        }
        let current=tx.query_row("SELECT day,app_version,os_version,source,sequence,seconds,views FROM counters WHERE installation=?1 AND bucket=?2",params![upload.installation_id,s.bucket_id],|r|Ok((r.get::<_,String>(0)?,r.get::<_,String>(1)?,r.get::<_,String>(2)?,r.get::<_,String>(3)?,r.get::<_,i64>(4)?,r.get::<_,i64>(5)?,r.get::<_,i64>(6)?))).optional().map_err(|_|unavailable)?;
        if let Some((day, version, os, source, sequence, seconds, views)) = current {
            if (day, version, os, source)
                != (
                    s.day.clone(),
                    s.app_version.clone(),
                    s.os_version.clone(),
                    s.source.clone(),
                )
                || (s.sequence > sequence
                    && (s.active_seconds < seconds || s.documents_viewed < views))
                || (s.sequence <= sequence
                    && (s.active_seconds > seconds || s.documents_viewed > views))
            {
                return Err(StatusCode::CONFLICT);
            }
        }
        tx.execute(
            "INSERT OR IGNORE INTO snapshots VALUES (?1,?2,?3,?4,?5)",
            params![
                upload.installation_id,
                s.bucket_id,
                s.sequence,
                now(),
                payload
            ],
        )
        .map_err(|_| unavailable)?;
        tx.execute("INSERT INTO counters VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9) ON CONFLICT(installation,bucket) DO UPDATE SET sequence=excluded.sequence,seconds=excluded.seconds,views=excluded.views WHERE excluded.sequence > counters.sequence",params![upload.installation_id,s.bucket_id,s.day,s.app_version,s.os_version,s.source,s.sequence,s.active_seconds,s.documents_viewed]).map_err(|_|unavailable)?;
        ack.insert(s.bucket_id.clone(), s.sequence.into());
    }
    tx.commit().map_err(|_| unavailable)?;
    Ok(serde_json::json!({"accepted":ack}))
}
use rusqlite::OptionalExtension;
pub async fn ingest(
    State(db): State<Db>,
    Json(upload): Json<Upload>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    tokio::task::spawn_blocking(move || {
        let mut connection = db.lock().map_err(|_| StatusCode::SERVICE_UNAVAILABLE)?;
        store(&mut connection, &upload)
    })
    .await
    .map_err(|_| StatusCode::SERVICE_UNAVAILABLE)?
    .map(Json)
}
pub fn summary(db: &Connection) -> rusqlite::Result<Vec<serde_json::Value>> {
    let mut q=db.prepare("SELECT day,app_version,os_version,source,count(DISTINCT installation),sum(seconds),sum(views) FROM counters GROUP BY 1,2,3,4 ORDER BY 1,2,3,4")?;
    let rows=q.query_map([],|r|Ok(serde_json::json!({"day":r.get::<_,String>(0)?,"app_version":r.get::<_,String>(1)?,"os_version":r.get::<_,String>(2)?,"source":r.get::<_,String>(3)?,"installations":r.get::<_,i64>(4)?,"active_seconds":r.get::<_,i64>(5)?,"documents_viewed":r.get::<_,i64>(6)?})))?.collect();
    rows
}
#[cfg(test)]
mod tests {
    use super::*;
    fn upload(seq: i64, views: i64) -> Upload {
        serde_json::from_value(serde_json::json!({"schema_version":2,"installation_id":"00000000-0000-4000-8000-000000000001","architecture":"arm64","channel":"unknown","snapshots":[{"bucket_id":"00000000-0000-4000-8000-000000000002","day":chrono::Utc::now().format("%Y-%m-%d").to_string(),"app_version":"1.37.596","os_version":"12.0","source":"app","sequence":seq,"active_seconds":views*10,"documents_viewed":views}]})).unwrap()
    }
    #[test]
    fn cumulative_retry_late_and_regression() {
        let mut db = open(&PathBuf::from(":memory:")).unwrap();
        store(&mut db, &upload(1, 10)).unwrap();
        store(&mut db, &upload(3, 30)).unwrap();
        store(&mut db, &upload(2, 20)).unwrap();
        store(&mut db, &upload(3, 30)).unwrap();
        assert_eq!(summary(&db).unwrap()[0]["documents_viewed"], 30);
        assert_eq!(store(&mut db, &upload(4, 25)), Err(StatusCode::CONFLICT));
        assert_eq!(store(&mut db, &upload(3, 31)), Err(StatusCode::CONFLICT));
        assert_eq!(
            db.query_row("SELECT count(*) FROM snapshots", [], |r| r.get::<_, i64>(0))
                .unwrap(),
            3
        );
    }
}

#[cfg(test)]
mod partition_tests {
    use super::*;
    #[test]
    fn partitions_and_atomic_invalid_batch() {
        let mut db = open(&PathBuf::from(":memory:")).unwrap();
        let mut u: Upload = serde_json::from_value(serde_json::json!({
            "schema_version":2,"installation_id":"00000000-0000-4000-8000-000000000001","architecture":"arm64","channel":"unknown",
            "snapshots":[{"bucket_id":"00000000-0000-4000-8000-000000000002","day":chrono::Utc::now().format("%Y-%m-%d").to_string(),"app_version":"1.0.1","os_version":"12.0","source":"app","sequence":1,"active_seconds":10,"documents_viewed":1}]
        })).unwrap();
        store(&mut db, &u).unwrap();
        u.snapshots[0].bucket_id = "00000000-0000-4000-8000-000000000003".into();
        u.snapshots[0].app_version = "1.1.2".into();
        u.snapshots[0].day =
            (chrono::Utc::now().date_naive() - chrono::Duration::days(1)).to_string();
        store(&mut db, &u).unwrap();
        assert_eq!(summary(&db).unwrap().len(), 2);
        let mut bad = u.snapshots[0].clone();
        bad.source = "private field".into();
        u.snapshots[0].sequence = 2;
        u.snapshots[0].documents_viewed = 2;
        u.snapshots.push(bad);
        assert_eq!(store(&mut db, &u), Err(StatusCode::BAD_REQUEST));
        let total: i64 = summary(&db)
            .unwrap()
            .iter()
            .map(|r| r["documents_viewed"].as_i64().unwrap())
            .sum();
        assert_eq!(total, 2);
    }
}
