import XCTest
import AppKit

private final class FeedbackGitHubFixture: URLProtocol {
    static var calls: [String] = []
    static var incident = UUID()
    static var handler: ((URLRequest) -> (Int, [String: String], Any))?
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "api.github.com" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if let handler = Self.handler {
            Self.calls.append(request.url!.absoluteString)
            let (code, headers, object) = handler(request)
            let data = try! JSONSerialization.data(withJSONObject: object, options: [.fragmentsAllowed])
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: headers)!, cacheStoragePolicy: .notAllowed)
            if code != 304 { client?.urlProtocol(self, didLoad: data) }
            client?.urlProtocolDidFinishLoading(self); return
        }
        let path = request.url!.path
        Self.calls.append(request.url!.absoluteString)
        let body: Any
        if path.hasSuffix("/comments") {
            body = [["id": 1001, "body": "Please attach a sample", "user": ["login": "maintainer"], "created_at": "2026-11-17T07:00:00Z"],
                    ["id": 1002, "body": "My own response", "user": ["login": "reporter"], "created_at": "2026-11-17T07:01:00Z"]]
        } else {
            let issue: [String: Any] = ["number": 73, "title": "Formula failure", "body": "Incident: \(Self.incident.uuidString)", "user": ["login": "reporter"], "created_at": "2026-11-17T06:00:00Z"]
            body = path.hasSuffix("/73") ? issue : [issue]
        }
        let data = try! JSONSerialization.data(withJSONObject: body)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["ETag": "fixture-v1"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
final class FeedbackFollowUpTests: XCTestCase {
    @MainActor func testRealControllerDiscoversIssueAndKeepsUnreadAfterSynchronizing() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let incident = ErrorIncident(kind: .math, source: .quicklook)
        FeedbackGitHubFixture.incident = incident.id; FeedbackGitHubFixture.calls = []; FeedbackGitHubFixture.handler = nil
        let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [FeedbackGitHubFixture.self]
        let controller = FeedbackFollowUpController(file: root.appendingPathComponent("state.json"), session: URLSession(configuration: configuration))
        let oldValue = UserDefaults.standard.object(forKey: "feedback.followReplies")
        defer {
            if let oldValue { UserDefaults.standard.set(oldValue, forKey: "feedback.followReplies") }
            else { UserDefaults.standard.removeObject(forKey: "feedback.followReplies") }
        }
        UserDefaults.standard.set(true, forKey: "feedback.followReplies")
        controller.register(incident)
        for _ in 0..<100 {
            if controller.unreadCount == 1 { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(controller.state.reports.first?.issue?.number, 73)
        XCTAssertEqual(controller.unreadCount, 1)
        XCTAssertTrue(FeedbackGitHubFixture.calls.contains { $0.contains("/issues?") && $0.contains("per_page=100") })
        XCTAssertTrue(FeedbackGitHubFixture.calls.contains { $0.contains("/issues/73/comments?") })
        let restored = try FeedbackFollowUpState.load(from: root.appendingPathComponent("state.json"))
        XCTAssertEqual(restored.unread.first?.url.fragment, "issuecomment-1001")
        XCTAssertEqual(restored.unread.count, 1)
    }
    func testMaterialContextNeverSubstitutesOtherLinesAndBoundsFragment() {
        let context = FeedbackMaterialContext.captured(document: "prose\n$$\nx^2\n$$\nend", url: nil, first: 2, last: 4)
        XCTAssertEqual(context.sample, "$$\nx^2\n$$")
        XCTAssertEqual(context.provenance, "captured-render-input")
        let refs = FeedbackMaterialContext.captured(document: "Reference $\\eqref{x}$\n\n$$x=1\\tag{A}\\label{x}$$", url: nil, first: 1, last: 1)
        XCTAssertTrue(refs.sample?.contains("label{x}") == true)
        XCTAssertNil(FeedbackMaterialContext.captured(document: "short", url: nil, first: 1, last: 99).sample)
        XCTAssertNil(FeedbackMaterialContext.captured(document: String(repeating: "x", count: 6001), url: nil, first: 1, last: 1).sample)
    }
    func testMaterialRequestRequiresExplicitMaterialReviewAndPreservesTrackingIdentityWithoutDiagnostics() throws {
        let incident = ErrorIncident(kind: .math, source: .quicklook)
        var request = IncidentFeedbackRequest(incident: incident, includeDiagnostics: false, notes: "")
        request.sample = "$$x$$"
        XCTAssertNil(IncidentFeedbackRequest.decode(try JSONEncoder().encode(request)))
        request.materialReview = true
        XCTAssertEqual(IncidentFeedbackRequest.decode(try JSONEncoder().encode(request))?.sample, "$$x$$")
        let query = URLComponents(url: incident.feedbackURL(includeDiagnostics: false), resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertTrue(query?.first(where: { $0.name == "body" })?.value?.contains("Incident: \(incident.id.uuidString)") == true)
    }
}

extension FeedbackFollowUpTests {
    @MainActor func testNativeMaterialWindowLayoutAndIncidentScopedFragment() throws {
        let registry = RendererErrorRegistry()
        let generation = registry.beginDocument()
        registry.sourceContext = { ("Private heading\n$$\nx^2\n$$\nOther text", nil) }
        let record: [String: Any] = ["action":"record", "kind":"math", "generation":generation, "id":"1", "reason":"mathSyntax", "lineStart":2, "lineEnd":4]
        XCTAssertNotNil(registry.receive(record))
        let previous = ErrorFeedback.materialPresenter
        defer { ErrorFeedback.materialPresenter = previous }
        var captured: IncidentDraft?
        ErrorFeedback.materialPresenter = { captured = $0 }
        var action = record; action["action"] = "materials"; registry.handle(action)
        let draft = try XCTUnwrap(captured)
        XCTAssertEqual(draft.materialContext?.sample, "$$\nx^2\n$$")
        XCTAssertFalse(draft.report.contains("Private heading"))
        let controller = FeedbackMaterialWindow(draft)
        let window = try XCTUnwrap(controller.window)
        if let screen = NSScreen.screens.dropFirst().first {
            window.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - window.frame.width/2, y: screen.visibleFrame.midY - window.frame.height/2))
        } else { window.setFrameOrigin(NSPoint(x: -10000, y: -10000)) }
        window.orderFront(nil)
        window.contentView?.layoutSubtreeIfNeeded()
        window.display()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        XCTAssertGreaterThan(window.contentView!.fittingSize.width, 0)
        XCTAssertFalse(window.contentView!.hasAmbiguousLayout)
        let output = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("build/issue-feedback/evidence").path
        do {
            try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
            let view = window.contentView!
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: output).appendingPathComponent("materials-view-cache.png"))
            if NSScreen.screens.count > 1 {
                let capture = Process(); capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                capture.arguments = ["-x", "-o", "-l", String(window.windowNumber), URL(fileURLWithPath: output).appendingPathComponent("materials.png").path]
                try capture.run(); capture.waitUntilExit()
                if capture.terminationStatus != 0 { print("NOTE native pixel capture unavailable; layout assertions remain verified") }
            }
        }
        window.close()
        _ = registry.beginDocument()
        XCTAssertNil(registry.sourceContext)
        XCTAssertNil(registry.receive(action))
    }
    @MainActor func testControllerClickAcknowledgesOnlyThatCommentAndFailedOpenPreservesBadge() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("state.json"), id = UUID(), date = Date()
        var state = FeedbackFollowUpState(); state.register(incident: id, date: date)
        try state.associate(incident: id, candidates: [FeedbackIssue(number: 73, title: "Test", body: "Incident: \(id.uuidString)", author: "reporter", createdAt: date)])
        state.merge(number: 73, replies: [FeedbackReply(id: 1, author: "maintainer", body: "First", createdAt: date), FeedbackReply(id: 2, author: "other", body: "Second", createdAt: date)])
        try state.save(to: file)
        var accepted = false, opened: URL?
        let controller = FeedbackFollowUpController(file: file, openURL: { opened = $0; return accepted })
        let clicked = try XCTUnwrap(controller.state.unread.first)
        controller.open(clicked); XCTAssertEqual(controller.unreadCount, 2)
        accepted = true; controller.open(clicked)
        XCTAssertEqual(opened?.fragment, "issuecomment-1")
        XCTAssertEqual(controller.state.unread.map(\.reply.id), [2])
        XCTAssertEqual(try FeedbackFollowUpState.load(from: file).unread.map(\.reply.id), [2])
    }
}

extension FeedbackFollowUpTests {
    @MainActor func testPaginationETagRateLimitAndOfflinePreserveUnread() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root); FeedbackGitHubFixture.handler = nil }
        let file = root.appendingPathComponent("state.json"), id = UUID(), date = Date(timeIntervalSince1970: 1_000)
        var state = FeedbackFollowUpState(); state.register(incident: id, date: date)
        try state.associate(incident: id, candidates: [FeedbackIssue(number: 73, title: "Test", body: "Incident: \(id.uuidString)", author: "reporter", createdAt: date)])
        try state.save(to: file)
        let oldEnabled = UserDefaults.standard.object(forKey: "feedback.followReplies")
        defer { if let oldEnabled { UserDefaults.standard.set(oldEnabled, forKey: "feedback.followReplies") } else { UserDefaults.standard.removeObject(forKey: "feedback.followReplies") } }
        UserDefaults.standard.set(true, forKey: "feedback.followReplies")
        var now = Date(), mode = 0, requests = 0, conditionalRequests = 0
        FeedbackGitHubFixture.handler = { request in
            requests += 1
            if mode == 2 { return (429, ["Retry-After":"1200"], ["message":"rate limited"]) }
            if mode == 3 { return (503, [:], ["message":"offline"]) }
            if request.value(forHTTPHeaderField: "If-None-Match") == "fixture-page" { conditionalRequests += 1; return (304, [:], []) }
            let page = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "page" }!.value!
            let rows: [[String: Any]] = page == "1" ? (1...100).map { ["id":$0, "body":"Reply", "user":["login":"other"], "created_at":"2026-11-17T07:00:00Z"] } : [["id":101, "body":"Last page", "user":["login":"maintainer"], "created_at":"2026-11-17T07:00:00Z"]]
            return (200, ["ETag":"fixture-page"], rows)
        }
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [FeedbackGitHubFixture.self]
        let controller = FeedbackFollowUpController(file: file, session: URLSession(configuration: config), now: { now })
        func settle() async throws { try await Task.sleep(nanoseconds: 150_000_000) }
        controller.refresh(force: true); try await settle()
        XCTAssertEqual(controller.unreadCount, 101, "all pages merged")
        now.addTimeInterval(301); mode = 1; controller.refresh(force: true); try await settle()
        // First incremental path differs from the initial cursor; next recheck reuses its ETag.
        now.addTimeInterval(301); controller.refresh(force: true); try await settle()
        XCTAssertGreaterThan(conditionalRequests, 0)
        XCTAssertEqual(controller.unreadCount, 101, "304 and duplicate pages never acknowledge")
        now.addTimeInterval(301); mode = 2; controller.refresh(force: true); try await settle()
        let afterLimit = requests
        now.addTimeInterval(301); controller.refresh(force: true); try await settle()
        XCTAssertEqual(requests, afterLimit, "Retry-After not bypassed by Check Now")
        XCTAssertEqual(controller.unreadCount, 101)
        now.addTimeInterval(1201); mode = 3; controller.refresh(force: true); try await settle()
        XCTAssertEqual(controller.unreadCount, 101)
        XCTAssertEqual(try FeedbackFollowUpState.load(from: file).unread.count, 101)
    }
    func testInvalidLineBoundsAreRejectedBeforeNativeSourceExtraction() {
        let registry = RendererErrorRegistry(); let generation = registry.beginDocument()
        registry.sourceContext = { ("secret", nil) }
        XCTAssertNil(registry.receive(["action":"record", "kind":"math", "generation":generation, "id":"1", "lineStart":-1, "lineEnd":Int.max]))
    }
}


extension FeedbackFollowUpTests {
    @MainActor func testPublicGitHubIssueReadbackWhenExplicitlyEnabled() async throws {
        guard ProcessInfo.processInfo.environment["FLUX_FEEDBACK_LIVE_READ"] == "1" else { throw XCTSkip("Explicit read-only live verification") }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("state.json"), id = UUID()
        var state = FeedbackFollowUpState(); state.register(incident: id, date: Date()); try state.save(to: file)
        let controller = FeedbackFollowUpController(file: file)
        controller.link("https://github.com/xykong/flux-markdown/issues/73", incident: id)
        for _ in 0..<200 {
            if controller.state.reports.first?.issue != nil { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertEqual(controller.state.reports.first?.issue?.number, 73)
        XCTAssertEqual(controller.state.reports.first?.issue?.author, "syutheoria")
        XCTAssertEqual(try FeedbackFollowUpState.load(from: file).reports.first?.issue?.number, 73)
    }
}

extension FeedbackFollowUpTests {
    @MainActor func testFeedbackDialogHasNoMenuAndOnlyShowsFailureRecoveryAfterFailure() async throws {
        let draft = IncidentDraft(ErrorIncident(kind: .math, source: .app))
        let controller = IncidentReportWindow(draft: draft)
        controller.updateStatus(failed: false)
        let window = try XCTUnwrap(controller.window)
        window.contentView?.layoutSubtreeIfNeeded()
        func visibleButtons(_ view: NSView) -> [NSButton] {
            if view.isHidden { return [] }
            return (view as? NSButton).map { [$0] } ?? view.subviews.flatMap(visibleButtons)
        }
        let titles = visibleButtons(window.contentView!).map(\.title)
        XCTAssertTrue(titles.contains(ErrorFeedback.text("Continue on GitHub…")))
        XCTAssertTrue(titles.contains(ErrorFeedback.text("Cancel")))
        XCTAssertFalse(titles.contains(ErrorFeedback.text("Copy Report")))
        XCTAssertFalse(titles.contains(ErrorFeedback.text("My Feedback")))
        XCTAssertFalse(titles.contains(ErrorFeedback.text("Include diagnostics")))
        if ProcessInfo.processInfo.environment["FLUX_DIALOG_VISUAL_HOLD"] == "1", let screen = NSScreen.screens.dropFirst().first {
            window.setFrameOrigin(NSPoint(x:screen.visibleFrame.midX-window.frame.width/2,y:screen.visibleFrame.midY-window.frame.height/2))
            window.orderFront(nil)
            print("Feedback native visual fixture PID \(ProcessInfo.processInfo.processIdentifier)")
            try await Task.sleep(nanoseconds: 30_000_000_000)
        }
        controller.updateStatus(failed: true)
        XCTAssertTrue(visibleButtons(window.contentView!).map(\.title).contains(ErrorFeedback.text("Copy Report")))
        window.close()
    }
}
