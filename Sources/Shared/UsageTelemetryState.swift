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
struct UsageUpload: Encodable {
    let schema_version: Int
    let timestamp: Int64
    let installation_id: String
    let architecture: String
    let channel: String
    let snapshots: [UsageSnapshot]
    enum CodingKeys: String, CodingKey { case schema_version, timestamp, installation_id, architecture, channel, snapshots }
    func encode(to encoder: Encoder) throws {
        struct Counter: Encodable {
            let bucket_id: String, app_version: String, os_version: String, source: String
            let day_start_timestamp: Int64
            let sequence: Int, active_seconds: Int, documents_viewed: Int
        }
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schema_version, forKey: .schema_version)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encode(installation_id, forKey: .installation_id)
        try c.encode(architecture, forKey: .architecture)
        try c.encode(channel, forKey: .channel)
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
        self = UsageTelemetryState(); enabled = value
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
    }
    mutating func prepare(at now: Date) -> UsageUpload? {
        guard enabled, now >= nextAttempt else { return nil }
        let dirty = Array(buckets.filter { $0.sequence > $0.acknowledged }.prefix(50))
        guard !dirty.isEmpty else { return nil }
        nextAttempt = now.addingTimeInterval(3600)
        #if arch(arm64)
        let architecture = "arm64"
        #else
        let architecture = "x86_64"
        #endif
        return UsageUpload(schema_version: 3, timestamp: Int64(now.timeIntervalSince1970.rounded(.down)), installation_id: installationID,
            architecture: architecture, channel: "unknown", snapshots: dirty)
    }
    mutating func acknowledge(_ upload: UsageUpload) {
        guard enabled, upload.installation_id == installationID else { return }
        for snapshot in upload.snapshots {
            if let index = buckets.firstIndex(where: { $0.bucket_id == snapshot.bucket_id }) {
                buckets[index].acknowledged = max(buckets[index].acknowledged, snapshot.sequence)
            }
        }
    }
}
