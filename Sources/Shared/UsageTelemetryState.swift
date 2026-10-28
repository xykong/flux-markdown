import Foundation

struct UsageSnapshot: Codable {
    var bucket_id: String
    var day: String
    var app_version: String
    var os_version: String
    var source: String
    var sequence: Int = 0
    var active_seconds: Int = 0
    var documents_viewed: Int = 0
    var acknowledged: Int = 0
    enum CodingKeys: String, CodingKey {
        case bucket_id, day, app_version, os_version, source, sequence, active_seconds, documents_viewed, acknowledged
    }
}
struct UsageLifecycle: Codable {
    let event_id: String
    let first_effective_at: Int64
    let first_effective_source: String
    let identity_origin: String
}
struct UsageUpload: Encodable {
    let schema_version: Int
    let timestamp: Int64
    let timezone_id: String?
    let installation_id: String
    let architecture: String
    let channel: String
    let snapshots: [UsageSnapshot]
    let lifecycle: UsageLifecycle?
    enum CodingKeys: String, CodingKey { case schema_version, timestamp, timezone_id, installation_id, architecture, channel, snapshots, lifecycle }
    func encode(to encoder: Encoder) throws {
        struct Counter: Encodable {
            let bucket_id: String, app_version: String, os_version: String, source: String
            let day_start_timestamp: Int64
            let sequence: Int, active_seconds: Int, documents_viewed: Int
        }
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schema_version, forKey: .schema_version)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encodeIfPresent(timezone_id, forKey: .timezone_id)
        try c.encode(installation_id, forKey: .installation_id)
        try c.encode(architecture, forKey: .architecture)
        try c.encode(channel, forKey: .channel)
        if schema_version == 4 { try c.encodeIfPresent(lifecycle, forKey: .lifecycle) }
        let counters = try snapshots.map { snapshot -> Counter in
            guard let start = UsageTelemetryState.dayStartTimestamp(snapshot.day) else {
                throw EncodingError.invalidValue(snapshot.day, .init(codingPath: encoder.codingPath, debugDescription: "Invalid UTC counter date"))
            }
            return Counter(bucket_id: snapshot.bucket_id, app_version: snapshot.app_version,
                os_version: snapshot.os_version, source: snapshot.source, day_start_timestamp: start,
                sequence: snapshot.sequence, active_seconds: snapshot.active_seconds, documents_viewed: snapshot.documents_viewed)
        }
        try c.encode(counters, forKey: .snapshots)
    }
}
struct UsageTelemetryState: Codable {
    var enabled = true
    var disclosed = false
    var installationID = UUID().uuidString.lowercased()
    var buckets: [UsageSnapshot] = []
    var activityEnd: [String: Date] = [:]
    var nextAttempt = Date.distantPast
    var lifecycle: UsageLifecycle?
    var identityOrigin = "fresh_state"
    var lifecycleAcknowledged = false
    var lifecycleRejection: String?
    var v4RetryAfter = Date.distantPast
    init() {}
    enum CodingKeys: String, CodingKey {
        case enabled, disclosed, installationID, buckets, activityEnd, nextAttempt
        case lifecycle, identityOrigin, lifecycleAcknowledged, lifecycleRejection, v4RetryAfter
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decode(Bool.self, forKey: .enabled)
        disclosed = try c.decode(Bool.self, forKey: .disclosed)
        installationID = try c.decode(String.self, forKey: .installationID)
        buckets = try c.decode([UsageSnapshot].self, forKey: .buckets)
        activityEnd = try c.decode([String: Date].self, forKey: .activityEnd)
        nextAttempt = try c.decode(Date.self, forKey: .nextAttempt)
        lifecycle = try c.decodeIfPresent(UsageLifecycle.self, forKey: .lifecycle)
        identityOrigin = try c.decodeIfPresent(String.self, forKey: .identityOrigin) ?? "upgraded_state"
        lifecycleAcknowledged = try c.decodeIfPresent(Bool.self, forKey: .lifecycleAcknowledged) ?? false
        lifecycleRejection = try c.decodeIfPresent(String.self, forKey: .lifecycleRejection)
        v4RetryAfter = try c.decodeIfPresent(Date.self, forKey: .v4RetryAfter) ?? .distantPast
    }
    var hasPendingLifecycle: Bool { lifecycle != nil && !lifecycleAcknowledged }
    func hasPendingUpload(at now: Date) -> Bool {
        buckets.contains { $0.sequence > $0.acknowledged } || (hasPendingLifecycle && now >= v4RetryAfter && !buckets.isEmpty)
    }
    static func day(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(secondsFromGMT: 0); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
    static func dayStartTimestamp(_ day: String) -> Int64? {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian); f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"; f.isLenient = false
        guard let date = f.date(from: day), f.string(from: date) == day else { return nil }
        return Int64(date.timeIntervalSince1970)
    }
    mutating func setEnabled(_ value: Bool) {
        guard value != enabled else { return }
        self = UsageTelemetryState(); enabled = value; identityOrigin = "opt_in_reset"
    }
    mutating func record(source: String, version: String, os: String, at date: Date, seconds: Int, views: Int) {
        guard enabled, seconds > 0 || views > 0 else { return }
        let day = Self.day(date)
        let cutoff = Self.day(date.addingTimeInterval(-90 * 86400))
        buckets.removeAll { $0.day < cutoff }
        if let index = buckets.firstIndex(where: { $0.day == day && $0.source == source && $0.app_version == version && $0.os_version == os }) {
            buckets[index].active_seconds += seconds; buckets[index].documents_viewed += views
            buckets[index].sequence += 1
        } else {
            guard buckets.count < 720 else { return }
            buckets.append(UsageSnapshot(bucket_id: UUID().uuidString.lowercased(), day: day,
                app_version: version, os_version: os, source: source, sequence: 1,
                active_seconds: seconds, documents_viewed: views))
        }
        if lifecycle == nil && ["fresh_state", "opt_in_reset"].contains(identityOrigin) {
            lifecycle = UsageLifecycle(event_id: UUID().uuidString.lowercased(), first_effective_at: Int64(date.timeIntervalSince1970.rounded(.down)), first_effective_source: source, identity_origin: identityOrigin)
        }
    }
    mutating func prepare(at now: Date, timeZone: TimeZone = .autoupdatingCurrent) -> UsageUpload? {
        guard enabled, now >= nextAttempt else { return nil }
        if let lifecycle, lifecycle.first_effective_at < Int64(now.timeIntervalSince1970) - 90 * 86400 {
            lifecycleAcknowledged = true; lifecycleRejection = "expired_local"
        }
        let version = now >= v4RetryAfter ? 4 : 3
        var dirty = Array(buckets.filter { $0.sequence > $0.acknowledged }.prefix(50))
        if dirty.isEmpty, hasPendingLifecycle, version == 4, let anchor = buckets.last { dirty = [anchor] }
        guard !dirty.isEmpty else { return nil }
        nextAttempt = now.addingTimeInterval(3600)
        #if arch(arm64)
        let architecture = "arm64"
        #else
        let architecture = "x86_64"
        #endif
        let zone = timeZone.identifier
        let knownZone = TimeZone.knownTimeZoneIdentifiers.contains(zone) || ["UTC", "GMT"].contains(zone)
        return UsageUpload(schema_version: version, timestamp: Int64(now.timeIntervalSince1970.rounded(.down)), timezone_id: knownZone ? zone : nil, installation_id: installationID,
            architecture: architecture, channel: "unknown", snapshots: dirty, lifecycle: version == 4 && hasPendingLifecycle ? lifecycle : nil)
    }
    mutating func acknowledge(_ upload: UsageUpload) {
        guard enabled, upload.installation_id == installationID else { return }
        for snapshot in upload.snapshots {
            if let index = buckets.firstIndex(where: { $0.bucket_id == snapshot.bucket_id }) {
                buckets[index].acknowledged = max(buckets[index].acknowledged, snapshot.sequence)
            }
        }
    }
    mutating func acknowledgeLifecycle(_ upload: UsageUpload, acknowledgement: [String: Any]?) {
        guard enabled, upload.installation_id == installationID,
              let sent = upload.lifecycle, let current = lifecycle,
              sent.event_id == current.event_id, let ack = acknowledgement,
              ack["event_id"] as? String == current.event_id,
              let status = ack["status"] as? String else { return }
        if status == "accepted" { lifecycleAcknowledged = true; lifecycleRejection = nil }
        else if status == "rejected" { lifecycleAcknowledged = true; lifecycleRejection = "server_rejected" }
    }
    mutating func markV4Unsupported(_ upload: UsageUpload, at now: Date) {
        guard enabled, upload.installation_id == installationID, upload.schema_version == 4 else { return }
        v4RetryAfter = now.addingTimeInterval(86400)
    }

}
