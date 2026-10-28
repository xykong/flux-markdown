import XCTest
import Foundation

final class UsageAttributionLifecycleTests: XCTestCase {
    private func json<T: Encodable>(_ value: T) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    }
    func testFirstPositiveUseCreatesStableV4Lifecycle() throws {
        let now = Date(timeIntervalSince1970: 1800000000)
        var state = UsageTelemetryState()
        state.record(source: "quicklook", version: "1.0.0", os: "15.0", at: now, seconds: 0, views: 0)
        XCTAssertNil(state.prepare(at: now))
        state.record(source: "quicklook", version: "1.0.0", os: "15.0", at: now, seconds: 0, views: 1)
        let first = try json(XCTUnwrap(state.prepare(at: now)))
        XCTAssertEqual(first["schema_version"] as? Int, 4)
        let lifecycle = try XCTUnwrap(first["lifecycle"] as? [String: Any])
        XCTAssertEqual(lifecycle["first_effective_at"] as? Int, 1800000000)
        XCTAssertEqual(lifecycle["first_effective_source"] as? String, "quicklook")
        XCTAssertEqual(lifecycle["identity_origin"] as? String, "fresh_state")
        state.record(source: "app", version: "1.0.0", os: "15.0", at: now.addingTimeInterval(10), seconds: 20, views: 1)
        var restored = try JSONDecoder().decode(UsageTelemetryState.self, from: JSONEncoder().encode(state))
        let retry = try json(XCTUnwrap(restored.prepare(at: now.addingTimeInterval(3600))))
        XCTAssertEqual((retry["lifecycle"] as? [String: Any])?["event_id"] as? String, lifecycle["event_id"] as? String)
    }
    func testExistingStateDoesNotBecomeNewAcquisitionOnUpgrade() throws {
        var original = UsageTelemetryState()
        let now = Date(timeIntervalSince1970: 1800000000)
        original.record(source: "app", version: "1.0.0", os: "15.0", at: now, seconds: 5, views: 1)
        var legacy = try json(original)
        for key in ["lifecycle", "identityOrigin", "lifecycleAcknowledged", "lifecycleRejection", "v4RetryAfter"] { legacy.removeValue(forKey: key) }
        var restored = try JSONDecoder().decode(UsageTelemetryState.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(try json(restored)["identityOrigin"] as? String, "upgraded_state")
        restored.record(source: "quicklook", version: "1.1.0", os: "15.0", at: now.addingTimeInterval(10), seconds: 1, views: 1)
        let upload = try json(XCTUnwrap(restored.prepare(at: now)))
        XCTAssertNil(upload["lifecycle"])
        XCTAssertEqual(restored.buckets.count, 2)
    }
    func testOptInResetIsNotFreshAcquisition() throws {
        var state = UsageTelemetryState()
        let oldID = state.installationID
        state.setEnabled(false)
        XCTAssertNil(state.prepare(at: Date()))
        state.setEnabled(true)
        XCTAssertNotEqual(state.installationID, oldID)
        let now = Date(timeIntervalSince1970: 1800000000)
        state.record(source: "app", version: "1.0.0", os: "15.0", at: now, seconds: 1, views: 1)
        let upload = try json(XCTUnwrap(state.prepare(at: now)))
        XCTAssertEqual((upload["lifecycle"] as? [String: Any])?["identity_origin"] as? String, "opt_in_reset")
    }
}

extension UsageAttributionLifecycleTests {
    func testCounterAndLifecycleAcknowledgementsAreIndependent() throws {
        let now = Date(timeIntervalSince1970: 1800000000)
        var state = UsageTelemetryState()
        state.record(source: "app", version: "1.0.0", os: "15.0", at: now, seconds: 10, views: 1)
        let initial = try XCTUnwrap(state.prepare(at: now))
        state.acknowledge(initial)
        let retry = try XCTUnwrap(state.prepare(at: now.addingTimeInterval(3600)))
        XCTAssertEqual(retry.snapshots[0].sequence, initial.snapshots[0].sequence)
        XCTAssertEqual(retry.snapshots[0].documents_viewed, 1)
        let id = try XCTUnwrap(retry.lifecycle?.event_id)
        state.acknowledgeLifecycle(retry, acknowledgement: ["event_id": id, "status": "retryable"])
        XCTAssertTrue(state.hasPendingLifecycle)
        state.acknowledgeLifecycle(retry, acknowledgement: ["event_id": UUID().uuidString, "status": "accepted"])
        XCTAssertTrue(state.hasPendingLifecycle)
        state.acknowledgeLifecycle(retry, acknowledgement: ["event_id": id, "status": "accepted"])
        XCTAssertFalse(state.hasPendingLifecycle)
        XCTAssertNil(state.prepare(at: now.addingTimeInterval(7200)))
    }
    func testExplicitV4FallbackIsLeasedAndDoesNotLoseLifecycle() throws {
        let now = Date(timeIntervalSince1970: 1800000000)
        var state = UsageTelemetryState()
        state.record(source: "quicklook", version: "1.0.0", os: "15.0", at: now, seconds: 0, views: 1)
        let first = try XCTUnwrap(state.prepare(at: now))
        state.markV4Unsupported(first, at: now)
        XCTAssertNil(state.prepare(at: now.addingTimeInterval(3599)))
        let legacy = try XCTUnwrap(state.prepare(at: now.addingTimeInterval(3600)))
        XCTAssertEqual(legacy.schema_version, 3)
        XCTAssertNil(try json(legacy)["lifecycle"])
        state.acknowledge(legacy)
        XCTAssertTrue(state.hasPendingLifecycle)
        XCTAssertNil(state.prepare(at: now.addingTimeInterval(7200)))
        let modern = try XCTUnwrap(state.prepare(at: now.addingTimeInterval(86400)))
        XCTAssertEqual(modern.schema_version, 4)
        XCTAssertEqual(modern.lifecycle?.event_id, first.lifecycle?.event_id)
        XCTAssertEqual(modern.snapshots[0].documents_viewed, 1)
    }
    func testRejectedOrExpiredLifecycleDoesNotRetryForever() throws {
        let now = Date(timeIntervalSince1970: 1800000000)
        var state = UsageTelemetryState()
        state.record(source: "app", version: "1.0.0", os: "15.0", at: now, seconds: 1, views: 1)
        let first = try XCTUnwrap(state.prepare(at: now))
        state.acknowledge(first)
        state.acknowledgeLifecycle(first, acknowledgement: ["event_id": try XCTUnwrap(first.lifecycle?.event_id), "status": "rejected"])
        XCTAssertNil(state.prepare(at: now.addingTimeInterval(3600)))
        var expired = UsageTelemetryState()
        expired.record(source: "app", version: "1.0.0", os: "15.0", at: now.addingTimeInterval(-91 * 86400), seconds: 1, views: 1)
        expired.record(source: "app", version: "1.0.0", os: "15.0", at: now, seconds: 1, views: 1)
        let upload = try XCTUnwrap(expired.prepare(at: now))
        XCTAssertNil(upload.lifecycle)
        XCTAssertEqual(upload.snapshots.count, 1)
    }
}
