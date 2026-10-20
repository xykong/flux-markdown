import XCTest
import AppKit

final class UsageTelemetryTests: XCTestCase {
    func testSnapshotsAreCumulativeAndAckCannotLoseNewUsage() {
        var state = UsageTelemetryState()
        let now = Date(timeIntervalSince1970: 1800000000)
        state.record(source: "app", version: "1.37.596", os: "11.7.10", at: now, seconds: 5, views: 1)
        let snapshot = state.prepare(at: now)!
        XCTAssertNil(state.prepare(at: now.addingTimeInterval(3599)))
        state.record(source: "app", version: "1.37.596", os: "11.7.10", at: now, seconds: 10, views: 1)
        state.acknowledge(snapshot)
        let next = state.prepare(at: now.addingTimeInterval(3600))!
        XCTAssertEqual(next.snapshots[0].active_seconds, 15)
        XCTAssertEqual(next.snapshots[0].documents_viewed, 2)
        state.acknowledge(next)
        XCTAssertNil(state.prepare(at: now.addingTimeInterval(7200)))
    }
    func testDayVersionSourceAndResetAreIndependent() {
        var state = UsageTelemetryState()
        let now = Date(timeIntervalSince1970: 1800000000)
        for (source, version, date) in [("app", "1.0.1", now), ("quicklook", "1.0.1", now), ("app", "1.1.2", now), ("app", "1.1.2", now.addingTimeInterval(86400))] {
            state.record(source: source, version: version, os: "12.0", at: date, seconds: 1, views: 1)
        }
        XCTAssertEqual(state.buckets.count, 4)
        let old = state.prepare(at: now)!
        state.setEnabled(false)
        XCTAssertTrue(state.buckets.isEmpty)
        state.record(source: "app", version: "1.0.1", os: "12.0", at: now, seconds: 5, views: 2)
        XCTAssertTrue(state.buckets.isEmpty)
        XCTAssertNil(state.prepare(at: now.addingTimeInterval(3600)))
        state.setEnabled(true)
        XCTAssertNotEqual(state.installationID, old.installation_id)
        state.acknowledge(old)
        XCTAssertTrue(state.buckets.isEmpty)
    }
    func testStateSurvivesPersistenceAndOfflineFailure() throws {
        var state = UsageTelemetryState()
        let now = Date()
        state.record(source: "quicklook", version: "1.0.1", os: "12.0", at: now, seconds: 30, views: 3)
        _ = state.prepare(at: now)
        var restored = try JSONDecoder().decode(UsageTelemetryState.self, from: JSONEncoder().encode(state))
        let retry = restored.prepare(at: now.addingTimeInterval(3600))!
        XCTAssertEqual(retry.snapshots[0].documents_viewed, 3)
        XCTAssertEqual(retry.snapshots[0].active_seconds, 30)
        XCTAssertFalse(String(data: try JSONEncoder().encode(retry), encoding: .utf8)!.contains("path"))
    }
}

extension UsageTelemetryTests {
    func testSharedWritersAndOptOutPersistAcrossInstances() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = UsageTelemetry(directory: root)
        let second = UsageTelemetry(directory: root)
        DispatchQueue.concurrentPerform(iterations: 40) { i in
            let store = i % 2 == 0 ? first : second
            store.transaction { $0.record(source: "app", version: "1.0.1", os: "12.0", at: Date(), seconds: 0, views: 1) }
        }
        XCTAssertEqual(first.transaction { $0.buckets.first?.documents_viewed }, 40)
        let now = Date()
        XCTAssertNotNil(first.transaction { $0.prepare(at: now) }!)
        XCTAssertNil(second.transaction { $0.prepare(at: now) }!)
        first.setEnabled(false)
        XCTAssertFalse(second.enabled)
        XCTAssertEqual(second.transaction { $0.buckets.count }, 0)
    }
    func testUTCMidnightSplitsUsage() {
        var state = UsageTelemetryState()
        let formatter = ISO8601DateFormatter()
        let before = formatter.date(from: "2026-10-19T23:59:59Z")!
        let after = before.addingTimeInterval(1)
        state.record(source: "quicklook", version: "1.0.1", os: "12.0", at: before, seconds: 1, views: 1)
        state.record(source: "quicklook", version: "1.0.1", os: "12.0", at: after, seconds: 1, views: 0)
        XCTAssertEqual(state.buckets.map(\.day), ["2026-10-19", "2026-10-20"])
        XCTAssertEqual(state.buckets.map(\.active_seconds), [1, 1])
    }
}

private final class UsageTestProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.handler else { return }
        let (code, data) = handler(request)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

extension UsageTelemetryTests {
    func testHTTPAcknowledgementAndNetworkFailurePreserveCounters() throws {
        for status in [200, 503] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [UsageTestProtocol.self]
            let store = UsageTelemetry(directory: root, configuration: config)
            let id = store.transaction { $0.installationID }!
            let delivered = expectation(description: "request \(status)")
            UsageTestProtocol.handler = { request in
                XCTAssertEqual(request.url?.path, "/v3/snapshots")
                let stream = request.httpBodyStream
                var body = request.httpBody ?? Data()
                if body.isEmpty, let stream {
                    stream.open(); defer { stream.close() }
                    var buffer = [UInt8](repeating: 0, count: 4096)
                    while stream.hasBytesAvailable {
                        let n = stream.read(&buffer, maxLength: buffer.count)
                        if n <= 0 { break }; body.append(contentsOf: buffer.prefix(n))
                    }
                }
                let payload = try! JSONSerialization.jsonObject(with: body) as! [String: Any]
                let snapshot = (payload["snapshots"] as! [[String: Any]])[0]
                XCTAssertNil(snapshot["acknowledged"])
                XCTAssertEqual(snapshot["documents_viewed"] as? Int, 1)
                let ack = try! JSONSerialization.data(withJSONObject: ["accepted": [snapshot["bucket_id"] as! String: snapshot["sequence"] as! Int]])
                delivered.fulfill()
                return (status, ack)
            }
            store.record(source: "app", seconds: 10, views: 1, installationID: id)
            wait(for: [delivered], timeout: 3)
            if status == 200 {
                let acknowledged = expectation(for: NSPredicate { _, _ in
                    store.transaction { $0.buckets.first?.acknowledged == 1 } == true
                }, evaluatedWith: nil)
                wait(for: [acknowledged], timeout: 3)
            }
            XCTAssertEqual(store.transaction { $0.buckets.first?.documents_viewed }, 1)
            if status == 503 { XCTAssertEqual(store.transaction { $0.buckets.first?.acknowledged }, 0) }
        }
        UsageTestProtocol.handler = nil
    }
}

extension UsageTelemetryTests {
    func testLocalRetentionAndCorruptStateFailClosed() throws {
        var state = UsageTelemetryState()
        let now = Date()
        state.record(source: "app", version: "1.0.1", os: "12.0", at: now.addingTimeInterval(-91 * 86400), seconds: 1, views: 1)
        state.record(source: "app", version: "1.0.1", os: "12.0", at: now, seconds: 1, views: 1)
        XCTAssertEqual(state.buckets.count, 1)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("invalid".utf8).write(to: root.appendingPathComponent("counters.json"))
        let store = UsageTelemetry(directory: root)
        XCTAssertFalse(store.enabled)
        XCTAssertNil(store.transaction { $0.prepare(at: now) })
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("counters.json")), "invalid")
    }
}

extension UsageTelemetryTests {
    func testVisibleSessionCountsOpeningButNotRerenderAndShowsOptOut() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [UsageTestProtocol.self]
        UsageTestProtocol.handler = { _ in (503, Data()) }
        defer { UsageTestProtocol.handler = nil }
        let store = UsageTelemetry(directory: root, configuration: config)
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 640, height: 320), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let view = NSView(frame: window.contentView!.bounds); window.contentView = view
        window.orderFrontRegardless()
        let session = UsageTelemetrySession(source: "quicklook", telemetry: store)
        defer { session.stop() }
        session.attach(view, document: URL(fileURLWithPath: "/synthetic-telemetry-fixture.md")); session.setHostVisible(true); session.rendered()
        let first = expectation(for: NSPredicate { _, _ in store.transaction { $0.buckets.first?.documents_viewed == 1 } == true }, evaluatedWith: nil)
        wait(for: [first], timeout: 5)
        XCTAssertTrue(store.transaction { $0.disclosed } == true)
        XCTAssertTrue(view.subviews.contains { $0 is NSStackView })
        session.rendering(); session.rendered()
        let stable = expectation(description: "rerender does not count")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { stable.fulfill() }
        wait(for: [stable], timeout: 3)
        XCTAssertEqual(store.transaction { $0.buckets.first?.documents_viewed }, 1)
        session.stop(); session.attach(view, document: URL(fileURLWithPath: "/synthetic-telemetry-fixture.md")); session.setHostVisible(true); session.rendered()
        let reopened = expectation(for: NSPredicate { _, _ in store.transaction { $0.buckets.first?.documents_viewed == 2 } == true }, evaluatedWith: nil)
        wait(for: [reopened], timeout: 5)
        let banner = try XCTUnwrap(view.subviews.compactMap { $0 as? NSStackView }.first)
        let buttons = banner.arrangedSubviews.compactMap { $0 as? NSStackView }.flatMap(\.arrangedSubviews).compactMap { $0 as? NSButton }
        try XCTUnwrap(buttons.first).performClick(nil)
        XCTAssertFalse(store.enabled)
        XCTAssertEqual(store.transaction { $0.buckets.count }, 0)
    }
}

extension UsageTelemetryTests {
    func testQuickPreviewClosedBeforeFirstTimerStillCounts() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [UsageTestProtocol.self]
        UsageTestProtocol.handler = { _ in (503, Data()) }
        defer { UsageTestProtocol.handler = nil }
        let store = UsageTelemetry(directory: root, configuration: config)
        store.transaction { $0.disclosed = true }
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 300))
        let session = UsageTelemetrySession(source: "quicklook", telemetry: store)
        session.attach(view, document: URL(fileURLWithPath: "/synthetic-quick-preview.md"))
        session.setHostVisible(true); session.rendered(); session.stop()
        let recorded = expectation(for: NSPredicate { _, _ in
            store.transaction { $0.buckets.first?.documents_viewed == 1 } == true
        }, evaluatedWith: nil)
        wait(for: [recorded], timeout: 2)
        XCTAssertEqual(store.transaction { $0.buckets.first?.active_seconds }, 0)
    }
}

extension UsageTelemetryTests {
    func testWireTimestampsAreUnixSecondsIndependentOfTimezoneAndDST() throws {
        let previous = NSTimeZone.default
        defer { NSTimeZone.default = previous }
        let parser = ISO8601DateFormatter()
        // Both sides of the US spring-forward and fall-back transitions, plus UTC midnight.
        for value in ["2026-03-08T06:59:59Z", "2026-03-08T07:00:00Z", "2026-11-01T05:59:59Z", "2026-11-01T06:00:00Z", "2026-10-19T23:59:59Z", "2026-10-20T00:00:00Z"] {
            let now = parser.date(from: value)!
            for zone in [TimeZone(secondsFromGMT: -12 * 3600)!, TimeZone(identifier: "Pacific/Kiritimati")!, TimeZone(identifier: "America/New_York")!, TimeZone(identifier: "Asia/Shanghai")!] {
                NSTimeZone.default = zone
                var state = UsageTelemetryState()
                state.record(source: "app", version: "1.0.1", os: "12.0", at: now, seconds: 10, views: 1)
                let body = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state.prepare(at: now)!)) as! [String: Any]
                XCTAssertEqual(body["timestamp"] as? Int64, Int64(now.timeIntervalSince1970))
                let counter = (body["snapshots"] as! [[String: Any]])[0]
                XCTAssertNil(counter["day"])
                XCTAssertEqual(counter["day_start_timestamp"] as? Int64, Int64(floor(now.timeIntervalSince1970 / 86400)) * 86400)
            }
        }
    }
    func testStoredCounterIdentitySurvivesTimestampWireUpgrade() throws {
        var state = UsageTelemetryState()
        let now = Date()
        state.record(source: "quicklook", version: "1.0.1", os: "12.0", at: now, seconds: 15, views: 2)
        let original = state.buckets[0]
        let data = try JSONEncoder().encode(state)
        var restored = try JSONDecoder().decode(UsageTelemetryState.self, from: data)
        let wire = restored.prepare(at: now)!
        XCTAssertEqual(wire.snapshots[0].bucket_id, original.bucket_id)
        XCTAssertEqual(wire.snapshots[0].sequence, original.sequence)
        XCTAssertEqual(wire.snapshots[0].documents_viewed, 2)
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(wire)) as! [String: Any]
        XCTAssertEqual(json["schema_version"] as? Int, 3)
    }
}

extension UsageTelemetryTests {
    func testTimezoneIsBatchMetadataAndDoesNotSplitCounters() throws {
        let previous = NSTimeZone.default
        defer { NSTimeZone.default = previous }
        var state = UsageTelemetryState()
        let now = Date()
        state.record(source: "app", version: "1.0.1", os: "12.0", at: now, seconds: 10, views: 1)
        NSTimeZone.default = TimeZone(identifier: "Asia/Shanghai")!
        let first = state.prepare(at: now, timeZone: TimeZone(identifier: "Asia/Shanghai")!)!
        NSTimeZone.default = TimeZone(identifier: "America/New_York")!
        let second = state.prepare(at: now.addingTimeInterval(3600), timeZone: TimeZone(identifier: "America/New_York")!)!
        for (upload, expected) in [(first,"Asia/Shanghai"),(second,"America/New_York")] {
            let body = try JSONSerialization.jsonObject(with: JSONEncoder().encode(upload)) as! [String: Any]
            XCTAssertEqual(body["timezone_id"] as? String, expected)
            XCTAssertNil(body["utc_offset_seconds"])
            let snapshot = (body["snapshots"] as! [[String: Any]])[0]
            XCTAssertNil(snapshot["timezone_id"])
            XCTAssertNil(snapshot["utc_offset_seconds"])
        }
        XCTAssertEqual(first.snapshots[0].bucket_id, second.snapshots[0].bucket_id)
        XCTAssertEqual(first.snapshots[0].sequence, second.snapshots[0].sequence)
    }
}
