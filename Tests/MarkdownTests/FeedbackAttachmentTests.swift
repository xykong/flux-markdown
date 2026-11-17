import XCTest
import CryptoKit
import AppKit

private final class AttachmentFixture: URLProtocol {
    static var paths: [String] = []
    static var bytes = Data("PK\u{03}\u{04}fixture".utf8)
    static var failUpload = false
    static var stored = false
    static var isPublic = true
    static let object = String(repeating: "a", count: 64)
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "t.xykong.cc" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.path; Self.paths.append((request.httpMethod ?? "GET") + " " + path)
        let receipt = FeedbackAttachmentReceipt(id: Self.object, url: Self.isPublic ? URL(string: "https://t.xykong.cc/feedback/files/\(Self.object).zip")! : nil, size: Self.bytes.count, sha256: FeedbackAttachmentClient.digest(Self.bytes), delete_token: String(repeating: "b", count: 64), expires_at: Int(Date().timeIntervalSince1970) + 604800, visibility: Self.isPublic ? "public" : "private")
        var code = 200; var data = try! JSONEncoder().encode(receipt)
        if path.hasSuffix("/uploads"), request.httpMethod == "GET", !Self.stored { code = 404 }
        if request.httpMethod == "POST" { if Self.failUpload { code = 503 } else { Self.stored = true } }
        if path.hasSuffix(".zip") { data = Self.bytes }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: [:])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
final class FeedbackAttachmentTests: XCTestCase {
    func testReceiptRejectsForeignHostsAndWrongBytes() throws {
        let good = FeedbackAttachmentReceipt(id: String(repeating: "a", count: 64), url: URL(string: "https://evil.example/feedback/files/a.zip")!, size: 10, sha256: String(repeating: "b", count: 64), delete_token: String(repeating: "c", count: 64), expires_at: 1)
        XCTAssertFalse(good.valid(size: 10, sha: String(repeating: "b", count: 64)))
    }
    func testAttachmentAndIncidentSurviveUnicodeURLBudget() {
        let incident = ErrorIncident(kind: .math, source: .quicklook)
        let link = URL(string: "https://t.xykong.cc/feedback/files/\(String(repeating: "a", count: 64)).zip")!
        let url = incident.feedbackURL(notes: String(repeating: "汉😀", count: 8000), attachment: link)
        XCTAssertLessThanOrEqual(url.absoluteString.utf8.count, 6000)
        let body = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "body" }!.value!
        XCTAssertTrue(body.contains(link.absoluteString)); XCTAssertTrue(body.contains(incident.id.uuidString))
    }
    func testUploadQueriesStatusFirstAndVerifiesFullDownload() async throws {
        AttachmentFixture.paths = []; AttachmentFixture.failUpload = false; AttachmentFixture.stored = false; AttachmentFixture.isPublic = true
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [AttachmentFixture.self]
        let client = FeedbackAttachmentClient(configuration: config)
        let receipt = try await client.upload(AttachmentFixture.bytes, incident: UUID(), key: String(repeating: "c", count: 64), sharePublic: true)
        XCTAssertEqual(receipt.sha256, FeedbackAttachmentClient.digest(AttachmentFixture.bytes))
        XCTAssertEqual(AttachmentFixture.paths, ["GET /feedback/uploads", "POST /feedback/uploads", "GET /feedback/files/\(AttachmentFixture.object).zip"])
        AttachmentFixture.paths = []
        _ = try await client.upload(AttachmentFixture.bytes, incident: UUID(), key: String(repeating: "c", count: 64), sharePublic: true)
        XCTAssertFalse(AttachmentFixture.paths.contains { $0.hasPrefix("POST") })
    }
    func testFailureDoesNotReturnReceiptAndCanRetrySameKey() async throws {
        AttachmentFixture.isPublic = true
        AttachmentFixture.paths = []; AttachmentFixture.failUpload = true; AttachmentFixture.stored = false; AttachmentFixture.isPublic = true
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [AttachmentFixture.self]
        let client = FeedbackAttachmentClient(configuration: config)
        do { _ = try await client.upload(AttachmentFixture.bytes, incident: UUID(), key: String(repeating: "d", count: 64), sharePublic: true); XCTFail("must fail") } catch { }
        AttachmentFixture.failUpload = false
        _ = try await client.upload(AttachmentFixture.bytes, incident: UUID(), key: String(repeating: "d", count: 64), sharePublic: true)
    }
}

extension FeedbackAttachmentTests {
    @MainActor func testNativeContinueOpensOnlyAfterVerifiedUploadAndKeepsFailedDraft() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FeedbackAttachmentJob.directoryOverride = root
        defer { FeedbackAttachmentJob.directoryOverride = nil; try? FileManager.default.removeItem(at: root) }
        AttachmentFixture.paths = []; AttachmentFixture.failUpload = true; AttachmentFixture.stored = false; AttachmentFixture.isPublic = false
        let draft = IncidentDraft(ErrorIncident(kind: .math, source: .app))
        draft.materialContext = FeedbackMaterialContext(document: "# Public fixture\n", sample: nil, originalURL: nil, provenance: "test", displayName: "document.md")
        let controller = IncidentReportWindow(draft: draft)
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [AttachmentFixture.self]
        controller.attachmentClient = { FeedbackAttachmentClient(configuration: config) }
        var opened = 0
        controller.openFeedback = { value in opened += 1; XCTAssertNil(value.uploadedAttachment); XCTAssertNotNil(value.uploadedAttachmentReference) }
        controller.perform(NSSelectorFromString("openPage"))
        for _ in 0..<200 {
            if AttachmentFixture.paths.contains("POST /feedback/uploads") { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(opened, 0)
        let job = try FeedbackAttachmentJob.load(draft.incident.id)
        XCTAssertEqual(job.document, "# Public fixture\n"); XCTAssertFalse(job.opened)
        // Mock response must describe the exact ZIP the real native controller prepared.
        AttachmentFixture.bytes = try Data(contentsOf: job.zip)
        AttachmentFixture.failUpload = false
        controller.perform(NSSelectorFromString("openPage"))
        for _ in 0..<200 { if opened > 0 { break }; try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertEqual(opened, 1)
        let saved = try FeedbackAttachmentJob.load(draft.incident.id)
        XCTAssertNotNil(saved.receipt); XCTAssertEqual(saved.key, job.key)
        controller.window?.close()
        AttachmentFixture.bytes = Data("PK\u{03}\u{04}fixture".utf8)
    }
}

extension FeedbackAttachmentTests {
    @MainActor func testLiveNativeAttachmentRoundTripWhenExplicitlyEnabled() async throws {
        guard ProcessInfo.processInfo.environment["FLUX_LIVE_ATTACHMENT"] == "1" else { throw XCTSkip("Explicit public-fixture upload only") }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FeedbackAttachmentJob.directoryOverride = root
        defer { FeedbackAttachmentJob.directoryOverride = nil }
        let draft = IncidentDraft(ErrorIncident(kind: .math, source: .app))
        draft.materialContext = FeedbackMaterialContext(document: "# Public attachment acceptance fixture\n\nNo user content.\n", sample: nil, originalURL: nil, provenance: "public-test-fixture", displayName: "public-fixture.md")
        draft.shareAttachment = true
        let controller = IncidentReportWindow(draft: draft)
        var form: URL?
        controller.openFeedback = { value in form = value.incident.feedbackURL(notes: value.notes, attachment: value.uploadedAttachment, attachmentReference: value.uploadedAttachmentReference) }
        controller.perform(NSSelectorFromString("openPage"))
        for _ in 0..<1800 { if form != nil { break }; try await Task.sleep(nanoseconds: 100_000_000) }
        let url = try XCTUnwrap(form)
        let job = try FeedbackAttachmentJob.load(draft.incident.id)
        let receipt = try XCTUnwrap(job.receipt)
        let out = URL(fileURLWithPath: "/tmp/flux-live-attachment-result.json")
        let data = try JSONSerialization.data(withJSONObject: ["form": url.absoluteString, "attachment": receipt.url!.absoluteString, "sha256": receipt.sha256, "job": job.folder.path, "deleteToken": receipt.delete_token, "id": receipt.id], options: .prettyPrinted)
        try data.write(to: out, options: .atomic); try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: out.path)
        let view = try XCTUnwrap(controller.window?.contentView)
        view.layoutSubtreeIfNeeded()
        if let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: rep)
            try rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "/tmp/flux-upload-native-dialog.png"))
        }
        controller.window?.close()
    }
}

extension FeedbackAttachmentTests {
    func testExplicitResourcesSurvivePackagingAndRestoredJobRetainsExactZIP() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FeedbackAttachmentJob.directoryOverride = root.appendingPathComponent("jobs")
        defer { FeedbackAttachmentJob.directoryOverride = nil; try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let resource = root.appendingPathComponent("image.png"); try Data("public image fixture".utf8).write(to: resource)
        let draft = IncidentDraft(ErrorIncident(kind: .math, source: .app)); draft.notes = "public fixture"
        draft.materialContext = FeedbackMaterialContext(document: "![image](image.png)", sample: nil, originalURL: root.appendingPathComponent("source.md"), provenance: "test")
        draft.attachmentResources = [resource]
        let zip = try draft.prepareDocumentAttachment(in: root.appendingPathComponent("packaged"))
        let first = try FeedbackAttachmentJob.prepare(draft, zip: zip)
        let unpack = Process(); let output = Pipe(); unpack.executableURL = URL(fileURLWithPath: "/usr/bin/unzip"); unpack.arguments = ["-p", first.zip.path, "image.png"]; unpack.standardOutput = output
        try unpack.run(); let contents = output.fileHandleForReading.readDataToEndOfFile(); unpack.waitUntilExit()
        XCTAssertEqual(String(data: contents, encoding: .utf8), "public image fixture")
        XCTAssertTrue(try FeedbackAttachmentJob.load(draft.incident.id).draft().restoredUpload)
        var empty = first; empty.notes = ""
        let restored = empty.draft(); restored.prepareDefaultContent(); XCTAssertEqual(restored.notes, "")
        XCTAssertEqual(try FeedbackAttachmentJob.prepare(draft, zip: draft.prepareDocumentAttachment(in: root.appendingPathComponent("packaged"))).key, first.key)
    }
}

extension FeedbackAttachmentTests {
    @MainActor func testNewDraftDefaultsPrivateAndPublishesOnlyReference() throws {
        let draft = IncidentDraft(ErrorIncident(kind: .math, source: .app))
        XCTAssertFalse(draft.shareAttachment)
        let controller = IncidentReportWindow(draft: draft)
        func buttons(_ v: NSView) -> [NSButton] { (v as? NSButton).map { [$0] } ?? v.subviews.flatMap(buttons) }
        let share = try XCTUnwrap(buttons(controller.window!.contentView!).first { $0.title == ErrorFeedback.text("Share attachment download link publicly") })
        XCTAssertEqual(share.state, .off)
        let ref = "FM-" + String(repeating: "a", count: 64)
        let url = draft.incident.feedbackURL(notes: String(repeating: "汉😀", count: 8000), attachmentReference: ref)
        let body = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "body" }!.value!
        XCTAssertTrue(body.contains(ref)); XCTAssertTrue(body.contains(draft.incident.id.uuidString)); XCTAssertFalse(body.contains("/feedback/files/")); XCTAssertLessThanOrEqual(url.absoluteString.utf8.count,6000)
        controller.window?.close()
    }
    func testPrivateUploadNeverDownloadsAndValidatesScope() async throws {
        AttachmentFixture.paths=[]; AttachmentFixture.failUpload=false; AttachmentFixture.stored=false; AttachmentFixture.isPublic=false
        let config=URLSessionConfiguration.ephemeral;config.protocolClasses=[AttachmentFixture.self]
        let client=FeedbackAttachmentClient(configuration:config)
        let receipt=try await client.upload(AttachmentFixture.bytes,incident:UUID(),key:String(repeating:"f",count:64))
        XCTAssertNil(receipt.url);XCTAssertEqual(receipt.visibility,"private")
        XCTAssertFalse(AttachmentFixture.paths.contains{$0.contains("/files/")})
        AttachmentFixture.isPublic=true
        do {_ = try await client.upload(AttachmentFixture.bytes,incident:UUID(),key:String(repeating:"f",count:64));XCTFail("reject different visibility")}catch{}
    }
}

extension FeedbackAttachmentTests {
    func testRestorationKeepsExplicitScopeAndNeverPublishesLegacyLinkByDefault() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FeedbackAttachmentJob.directoryOverride=root
        defer {FeedbackAttachmentJob.directoryOverride=nil;try? FileManager.default.removeItem(at:root)}
        let draft=IncidentDraft(ErrorIncident(kind:.math,source:.app));draft.materialContext=FeedbackMaterialContext(document:"# fixture",sample:nil,originalURL:nil,provenance:"test")
        let zip=try draft.prepareDocumentAttachment();var job=try FeedbackAttachmentJob.prepare(draft,zip:zip)
        XCTAssertFalse(try FeedbackAttachmentJob.load(draft.incident.id).draft().shareAttachment)
        draft.shareAttachment=true
        XCTAssertThrowsError(try FeedbackAttachmentJob.prepare(draft,zip:zip))
        job.sharePublic=true;try job.save();XCTAssertTrue(try FeedbackAttachmentJob.load(draft.incident.id).draft().shareAttachment)
        job.sharePublic=nil;job.receipt=FeedbackAttachmentReceipt(id:String(repeating:"a",count:64),url:URL(string:"https://t.xykong.cc/feedback/files/\(String(repeating:"a",count:64)).zip"),size:1,sha256:String(repeating:"b",count:64),delete_token:String(repeating:"c",count:64),expires_at:1)
        let restored=job.draft();XCTAssertFalse(restored.shareAttachment);XCTAssertNil(restored.uploadedAttachment)
    }
    @MainActor func testLivePrivateNativeSubmissionWhenExplicitlyEnabled() async throws {
        guard ProcessInfo.processInfo.environment["FLUX_LIVE_PRIVATE_ATTACHMENT"]=="1" else {throw XCTSkip("Explicit non-sensitive private fixture only")}
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);FeedbackAttachmentJob.directoryOverride=root
        defer {FeedbackAttachmentJob.directoryOverride=nil}
        let draft=IncidentDraft(ErrorIncident(kind:.math,source:.app));draft.materialContext=FeedbackMaterialContext(document:"# Non-sensitive private delivery fixture\nOnly maintainers may retrieve this fixture.\n",sample:nil,originalURL:nil,provenance:"private-test-fixture",displayName:"private-fixture.md")
        let controller=IncidentReportWindow(draft:draft);var form:URL?
        controller.openFeedback={value in form=value.incident.feedbackURL(notes:value.notes,attachmentReference:value.uploadedAttachmentReference);XCTAssertNil(value.uploadedAttachment)}
        controller.perform(NSSelectorFromString("openPage"))
        for _ in 0..<1800 {if form != nil {break};try await Task.sleep(nanoseconds:100_000_000)}
        let url=try XCTUnwrap(form);let job=try FeedbackAttachmentJob.load(draft.incident.id);let receipt=try XCTUnwrap(job.receipt)
        XCTAssertNil(receipt.url);XCTAssertEqual(receipt.visibility,"private")
        let path=URL(fileURLWithPath:"/tmp/flux-private-live-result.json")
        let data=try JSONSerialization.data(withJSONObject:["form":url.absoluteString,"reference":receipt.reference,"id":receipt.id,"sha256":receipt.sha256,"deleteToken":receipt.delete_token,"uploadKey":job.key,"job":job.folder.path],options:.prettyPrinted)
        try data.write(to:path,options:.atomic);try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:path.path)
        controller.window?.close()
    }
}
