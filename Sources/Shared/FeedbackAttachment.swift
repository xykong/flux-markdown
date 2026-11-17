import Foundation
import CryptoKit

struct FeedbackAttachmentReceipt: Codable {
    let id: String
    let url: URL
    let size: Int
    let sha256: String
    let delete_token: String
    let expires_at: Int
    func valid(size: Int, sha: String) -> Bool {
        Self.hex(id) && Self.hex(delete_token) && self.size == size && sha256 == sha
            && url.absoluteString == "https://t.xykong.cc/feedback/files/\(id).zip"
    }
    static func hex(_ value: String) -> Bool { value.utf8.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) } }
}
enum FeedbackAttachmentError: Error { case invalid, http(Int), tooLarge, busy }

/// Fixed HTTPS origin, no cookies, credentials or redirects. The complete downloaded
/// bytes must match the local ZIP before its link may enter the GitHub form.
private final class FeedbackNoRedirect: NSObject, URLSessionTaskDelegate {
    static let shared = FeedbackNoRedirect()
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
final class FeedbackAttachmentClient {
    private var session: URLSession!
    init(configuration: URLSessionConfiguration = .ephemeral) {
        configuration.httpCookieStorage = nil; configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil; configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 90; configuration.timeoutIntervalForResource = 180
        session = URLSession(configuration: configuration, delegate: FeedbackNoRedirect.shared, delegateQueue: nil)
    }
    deinit { session.invalidateAndCancel() }
    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private func request(_ path: String, method: String = "GET", headers: [String: String] = [:], body: Data? = nil) -> URLRequest {
        var r = URLRequest(url: URL(string: "https://t.xykong.cc/feedback/" + path)!); r.httpMethod = method; r.httpBody = body
        r.setValue("FluxMarkdown-Feedback", forHTTPHeaderField: "User-Agent")
        for (key, value) in headers { r.setValue(value, forHTTPHeaderField: key) }; return r
    }
    private func send(_ request: URLRequest) async throws -> (Data, Int) {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { continuation in
            session.dataTask(with: request) { data, response, error in
                if let error { continuation.resume(throwing: error); return }
                guard let response = response as? HTTPURLResponse, response.url == request.url, let data, data.count <= 25 * 1024 * 1024 else { continuation.resume(throwing: FeedbackAttachmentError.invalid); return }
                continuation.resume(returning: (data, response.statusCode))
            }.resume()
        }
    }
    func upload(_ bytes: Data, incident: UUID, key: String) async throws -> FeedbackAttachmentReceipt {
        guard !bytes.isEmpty, bytes.count <= 25 * 1024 * 1024, FeedbackAttachmentReceipt.hex(key) else { throw FeedbackAttachmentError.tooLarge }
        let sha = Self.digest(bytes)
        // Every retry reconciles the original capability first, including after a timeout/restart.
        let (statusData, status) = try await send(request("uploads", headers: ["X-Upload-Key": key]))
        let data: Data
        if status == 200 { data = statusData }
        else if status == 404 {
            try Task.checkCancellation()
            let (posted, code) = try await send(request("uploads", method: "POST", headers: ["Content-Type": "application/zip", "X-Incident-ID": incident.uuidString, "X-Upload-Key": key, "X-Content-SHA256": sha], body: bytes))
            guard code == 200 else { throw FeedbackAttachmentError.http(code) }; data = posted
        } else { throw FeedbackAttachmentError.http(status) }
        let receipt = try JSONDecoder().decode(FeedbackAttachmentReceipt.self, from: data)
        guard receipt.valid(size: bytes.count, sha: sha) else { throw FeedbackAttachmentError.invalid }
        try Task.checkCancellation()
        let (download, code) = try await send(request("files/\(receipt.id).zip"))
        guard code == 200, download.count == bytes.count, Self.digest(download) == sha else { throw FeedbackAttachmentError.invalid }
        return receipt
    }
    func lookup(_ bytes: Data, key: String) async throws -> FeedbackAttachmentReceipt? {
        let (data, code) = try await send(request("uploads", headers: ["X-Upload-Key": key]))
        if code == 404 { return nil }
        guard code == 200 else { throw FeedbackAttachmentError.http(code) }
        let receipt = try JSONDecoder().decode(FeedbackAttachmentReceipt.self, from: data)
        guard receipt.valid(size: bytes.count, sha: Self.digest(bytes)) else { throw FeedbackAttachmentError.invalid }
        return receipt
    }
    func delete(_ receipt: FeedbackAttachmentReceipt) async throws {
        guard receipt.valid(size: receipt.size, sha: receipt.sha256) else { throw FeedbackAttachmentError.invalid }
        let (_, code) = try await send(request("objects/\(receipt.id)", method: "DELETE", headers: ["X-Delete-Token": receipt.delete_token]))
        guard code == 204 || code == 404 else { throw FeedbackAttachmentError.http(code) }
    }
    func associate(_ receipt: FeedbackAttachmentReceipt, issue: Int) async throws {
        guard receipt.valid(size: receipt.size, sha: receipt.sha256) else { throw FeedbackAttachmentError.invalid }
        let data = try JSONSerialization.data(withJSONObject: ["issue": issue])
        let (_, code) = try await send(request("objects/\(receipt.id)/issue", method: "POST", headers: ["X-Delete-Token": receipt.delete_token, "Content-Type": "application/json"], body: data))
        guard code == 204 else { throw FeedbackAttachmentError.http(code) }
    }
}

/// Private crash-recovery journal: capability never appears in a public URL/log.
struct FeedbackAttachmentJob: Codable {
    var incident: ErrorIncident
    var notes: String
    var includeDiagnostics: Bool
    var document: String
    var displayName: String
    var fingerprint: String
    var key: String
    var receipt: FeedbackAttachmentReceipt?
    var opened = false
    var linked = false
    var created = Date()
    static var directoryOverride: URL?
    static var root: URL { directoryOverride ?? SharedPreferenceStore.applicationSupportDirectory().appendingPathComponent("FeedbackUploads", isDirectory: true) }
    var folder: URL { Self.root.appendingPathComponent(incident.id.uuidString, isDirectory: true) }
    var zip: URL { folder.appendingPathComponent("reproduction.zip") }
    static func load(_ id: UUID) throws -> Self {
        let url = root.appendingPathComponent(id.uuidString).appendingPathComponent("job.json")
        let data = try Data(contentsOf: url)
        guard data.count <= 32 * 1024 * 1024 else { throw FeedbackAttachmentError.tooLarge }
        let job = try JSONDecoder().decode(Self.self, from: data)
        guard job.incident.id == id, job.incident.isValid, FeedbackAttachmentReceipt.hex(job.key) else { throw FeedbackAttachmentError.invalid }; return job
    }
    func save() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: Self.root.path)
        let url = folder.appendingPathComponent("job.json")
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    static func prepare(_ draft: IncidentDraft, zip: URL) throws -> Self {
        let fingerprint = draft.attachmentFingerprint ?? FeedbackAttachmentClient.digest(Data((draft.materialContext?.document ?? "").utf8) + Data(draft.report.utf8))
        if let previous = try? load(draft.incident.id), previous.fingerprint == fingerprint, FileManager.default.fileExists(atPath: previous.zip.path) { return previous }
        // Retain any already uploaded revision and its delete capability, rather than overwriting it.
        if (try? load(draft.incident.id)) != nil { throw FeedbackAttachmentError.busy }
        let root = Self.root
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let count = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).count
        guard count < 100 || FileManager.default.fileExists(atPath: root.appendingPathComponent(draft.incident.id.uuidString).path) else { throw FeedbackAttachmentError.busy }
        let key = (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "").lowercased()
        let job = Self(incident: draft.incident, notes: draft.notes, includeDiagnostics: draft.includeDiagnostics, document: draft.materialContext?.document ?? "", displayName: draft.documentName, fingerprint: fingerprint, key: key)
        try job.save(); try Data(contentsOf: zip).write(to: job.zip, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: job.zip.path)
        return job
    }
    static func all() -> [Self] {
        let children = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        return children.prefix(100).compactMap { UUID(uuidString: $0.lastPathComponent).flatMap { try? load($0) } }
    }
    func draft() -> IncidentDraft {
        let draft = IncidentDraft(incident); draft.restoreNotes(notes); draft.includeDiagnostics = includeDiagnostics
        draft.materialContext = FeedbackMaterialContext(document: document, sample: nil, originalURL: nil, provenance: "restored-feedback-draft", displayName: displayName)
        draft.attachmentURL = zip; draft.restoredUpload = true; draft.attachmentFingerprint = fingerprint; draft.uploadedAttachment = receipt?.url
        return draft
    }
    static func associate(incident: UUID, issue: Int) {
        guard let job = try? load(incident), !job.linked, let receipt = job.receipt else { return }
        Task {
            do {
                try await FeedbackAttachmentClient().associate(receipt, issue: issue)
                var current = try load(incident)
                guard current.key == job.key else { return }; current.linked = true; try current.save()
            } catch { /* Retain capability; the next public Issue synchronization retries. */ }
        }
    }
}
