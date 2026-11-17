import Foundation

struct FeedbackIssue: Codable, Equatable {
    let number: Int
    let title: String
    let body: String
    let author: String
    let createdAt: Date
    static func number(from url: URL) -> Int? {
        guard url.scheme == "https", url.host == "github.com", url.user == nil, url.password == nil, url.port == nil else { return nil }
        let parts = url.path.split(separator: "/")
        guard parts.count == 4, parts[0] == "xykong", parts[1] == "flux-markdown", parts[2] == "issues",
              let number = Int(parts[3]), number > 0 else { return nil }
        return number
    }
    var url: URL { URL(string: "https://github.com/xykong/flux-markdown/issues/\(number)")! }
}
struct FeedbackReply: Codable, Equatable {
    let id: Int64
    let author: String
    let body: String
    let createdAt: Date
}
struct FeedbackTrackedReport: Codable, Identifiable {
    var id: UUID { incident }
    let incident: UUID
    let date: Date
    var issue: FeedbackIssue?
    var replies: [FeedbackReply] = []
    var acknowledged: Set<Int64> = []
}
struct FeedbackUnreadReply: Identifiable {
    let incident: UUID
    let issue: FeedbackIssue
    let reply: FeedbackReply
    var id: String { "\(issue.number):\(reply.id)" }
    var url: URL { URL(string: "https://github.com/xykong/flux-markdown/issues/\(issue.number)#issuecomment-\(reply.id)")! }
}
enum FeedbackStateError: Error { case association, invalidData }
struct FeedbackFollowUpState: Codable {
    private(set) var reports: [FeedbackTrackedReport] = []
    mutating func register(incident: UUID, date: Date) {
        guard !reports.contains(where: { $0.incident == incident }) else { return }
        reports.append(FeedbackTrackedReport(incident: incident, date: date))
    }
    mutating func associate(incident: UUID, candidates: [FeedbackIssue], manual: Bool = false) throws {
        let matches = candidates.filter { issue in
            guard issue.number > 0 else { return false }
            return manual || issue.body.components(separatedBy: .newlines).contains { $0.trimmingCharacters(in: .whitespacesAndNewlines) == "Incident: \(incident.uuidString)" }
        }
        guard matches.count == 1, let index = reports.firstIndex(where: { $0.incident == incident }),
              !reports.contains(where: { $0.incident != incident && $0.issue?.number == matches[0].number }) else { throw FeedbackStateError.association }
        if let existing = reports[index].issue, existing.number != matches[0].number { throw FeedbackStateError.association }
        reports[index].issue = matches[0]
    }
    mutating func merge(number: Int, replies: [FeedbackReply]) {
        guard let index = reports.firstIndex(where: { $0.issue?.number == number }), let issue = reports[index].issue else { return }
        var known = Dictionary(uniqueKeysWithValues: reports[index].replies.map { ($0.id, $0) })
        for reply in replies where reply.id > 0 && reply.author != issue.author && reply.createdAt >= issue.createdAt {
            // Existing comment edits do not create another reminder.
            if known[reply.id] == nil { known[reply.id] = reply }
        }
        reports[index].replies = known.values.sorted { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) }
    }
    var unread: [FeedbackUnreadReply] {
        reports.flatMap { report -> [FeedbackUnreadReply] in
            guard let issue = report.issue else { return [] }
            return report.replies.filter { !report.acknowledged.contains($0.id) }.map { FeedbackUnreadReply(incident: report.incident, issue: issue, reply: $0) }
        }.sorted { ($0.reply.createdAt, $0.reply.id) < ($1.reply.createdAt, $1.reply.id) }
    }
    @discardableResult mutating func activate(_ item: FeedbackUnreadReply, open: (URL) -> Bool) -> Bool {
        guard let index = reports.firstIndex(where: { $0.incident == item.incident && $0.issue?.number == item.issue.number }),
              reports[index].replies.contains(where: { $0.id == item.reply.id }), open(item.url) else { return false }
        reports[index].acknowledged.insert(item.reply.id)
        return true
    }
    func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(self)
        guard data.count <= 8 * 1024 * 1024 else { throw CocoaError(.fileWriteOutOfSpace) }
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    static func load(from url: URL) throws -> Self {
        let data = try BoundedFileReader.read(url, maxBytes: 8 * 1024 * 1024)
        let state = try JSONDecoder().decode(Self.self, from: data)
        guard Set(state.reports.map(\.incident)).count == state.reports.count,
              state.reports.allSatisfy({ report in
                  (report.issue == nil || report.issue!.number > 0) && Set(report.replies.map(\.id)).count == report.replies.count && report.replies.allSatisfy { $0.id > 0 }
              }) else { throw FeedbackStateError.invalidData }
        return state
    }
}
