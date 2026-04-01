import XCTest

@MainActor
final class WindowSizePersistenceTests: XCTestCase {

    // MARK: - Size Validation Tests

    func testSizeValidation_RejectsTinySizes() {
        // Sizes that should be rejected as "near-minimum accidental sizes"
        let tinySizes = [
            CGSize(width: 203, height: 269),  // From user log
            CGSize(width: 200, height: 200),  // Current threshold
            CGSize(width: 150, height: 150),  // Below threshold
            CGSize(width: 100, height: 300),  // One dimension below
            CGSize(width: 400, height: 100),  // Other dimension below
        ]

        for size in tinySizes {
            XCTAssertFalse(
                PreviewViewController.isSizeValidForPersistence(size),
                "Size \(size.width)x\(size.height) should be rejected as too small"
            )
        }
    }

    func testSizeValidation_AcceptsReasonableSizes() {
        // Sizes that should be accepted
        let validSizes = [
            CGSize(width: 320, height: 240),  // New minimum threshold
            CGSize(width: 360, height: 300),  // Alternative minimum
            CGSize(width: 800, height: 600),  // Typical size
            CGSize(width: 1200, height: 800), // Large size
        ]

        for size in validSizes {
            XCTAssertTrue(
                PreviewViewController.isSizeValidForPersistence(size),
                "Size \(size.width)x\(size.height) should be accepted as valid"
            )
        }
    }

    func testSizeValidation_ExactlyAtThreshold() {
        // Test boundary conditions
        let threshold = PreviewViewController.minimumPersistedWindowSize

        // At threshold should be valid
        XCTAssertTrue(
            PreviewViewController.isSizeValidForPersistence(threshold),
            "Size exactly at threshold \(threshold.width)x\(threshold.height) should be valid"
        )

        // Just below threshold should be invalid
        let justBelow = CGSize(width: threshold.width - 1, height: threshold.height - 1)
        XCTAssertFalse(
            PreviewViewController.isSizeValidForPersistence(justBelow),
            "Size just below threshold \(justBelow.width)x\(justBelow.height) should be invalid"
        )
    }

    // MARK: - Window Resize Intent Tests

    func testWindowResizeIntent_OnlySavesWithMatchingStartAndEnd() {
        // This test verifies the concept that we only save if we saw
        // a matching willStartLiveResize for the same window

        let window1 = NSWindow()
        let window2 = NSWindow()

        // Simulate seeing start for window1
        let window1Id = ObjectIdentifier(window1)
        var seenStartForWindow: ObjectIdentifier? = window1Id

        // End event for window1 should be allowed to save
        let endWindow1Id = ObjectIdentifier(window1)
        let shouldSave1 = (seenStartForWindow == endWindow1Id)
        XCTAssertTrue(shouldSave1, "Should save when start and end match")

        // End event for window2 should NOT be allowed to save
        let endWindow2Id = ObjectIdentifier(window2)
        let shouldSave2 = (seenStartForWindow == endWindow2Id)
        XCTAssertFalse(shouldSave2, "Should NOT save when start and end don't match")

        // No start event should NOT allow save
        seenStartForWindow = nil
        let shouldSave3 = (seenStartForWindow != nil)
        XCTAssertFalse(shouldSave3, "Should NOT save when no start event seen")
    }

    func testWindowResizeIntent_ResetsAfterMismatch() {
        // If we see an end event without a matching start,
        // we should reset the flag to prevent false positives

        var seenStartForWindow: ObjectIdentifier? = ObjectIdentifier(NSWindow())

        // Simulate mismatched end event (different window)
        let mismatchedEndId = ObjectIdentifier(NSWindow())
        if seenStartForWindow != mismatchedEndId {
            seenStartForWindow = nil  // Reset
        }

        XCTAssertNil(seenStartForWindow, "Flag should reset after mismatched end event")

        // Subsequent end events should also be rejected
        let anotherEndId = ObjectIdentifier(NSWindow())
        let shouldSave = (seenStartForWindow == anotherEndId)
        XCTAssertFalse(shouldSave, "Should NOT save after flag reset")
    }

    // MARK: - Restore Clamp Tests

    func testRestoreClamp_IgnoresTinyPersistedSizes() {
        let tinySizes = [
            CGSize(width: 203, height: 269),
            CGSize(width: 200, height: 200),
            CGSize(width: 150, height: 300),
        ]

        for tinySize in tinySizes {
            let clampedSize = PreviewViewController.clampPersistedSizeForRestore(tinySize)

            // Should return nil to indicate "use default"
            XCTAssertNil(
                clampedSize,
                "Tiny persisted size \(tinySize.width)x\(tinySize.height) should be ignored (return nil)"
            )
        }
    }

    func testRestoreClamp_AcceptsValidPersistedSizes() {
        let validSizes = [
            CGSize(width: 320, height: 240),
            CGSize(width: 800, height: 600),
            CGSize(width: 1200, height: 800),
        ]

        for validSize in validSizes {
            let clampedSize = PreviewViewController.clampPersistedSizeForRestore(validSize)

            XCTAssertNotNil(clampedSize, "Valid size should not be nil")
            XCTAssertEqual(
                clampedSize?.width, validSize.width,
                "Valid size width should be unchanged"
            )
            XCTAssertEqual(
                clampedSize?.height, validSize.height,
                "Valid size height should be unchanged"
            )
        }
    }

    func testRestoreClamp_HandlesNilInput() {
        let result = PreviewViewController.clampPersistedSizeForRestore(nil)
        XCTAssertNil(result, "Nil input should return nil")
    }

    func testAutoClearInvalidPersistedSize_ShouldClearInvalidSize() {
        let invalidSizes = [
            CGSize(width: 203, height: 269),
            CGSize(width: 200, height: 200),
            CGSize(width: 150, height: 300),
        ]

        for invalidSize in invalidSizes {
            let shouldClear = PreviewViewController.shouldClearInvalidPersistedSize(invalidSize)
            XCTAssertTrue(
                shouldClear,
                "Invalid size \(invalidSize.width)x\(invalidSize.height) should be marked for clearing"
            )
        }
    }

    func testAutoClearInvalidPersistedSize_ShouldNotClearValidSize() {
        let validSizes = [
            CGSize(width: 320, height: 240),
            CGSize(width: 800, height: 600),
            CGSize(width: 1200, height: 800),
        ]

        for validSize in validSizes {
            let shouldClear = PreviewViewController.shouldClearInvalidPersistedSize(validSize)
            XCTAssertFalse(
                shouldClear,
                "Valid size \(validSize.width)x\(validSize.height) should NOT be marked for clearing"
            )
        }
    }

    func testAutoClearInvalidPersistedSize_ShouldNotClearNil() {
        let shouldClear = PreviewViewController.shouldClearInvalidPersistedSize(nil)
        XCTAssertFalse(shouldClear, "Nil size should NOT be marked for clearing")
    }

    // MARK: - Auto-Clear Integration Tests

    func testAutoClearIntegration_InvalidPersistedSizeClearedOnViewControllerLoad() {
        let originalSize = AppearancePreference.shared.quickLookSize
        defer {
            AppearancePreference.shared.quickLookSize = originalSize
        }

        let invalidSize = CGSize(width: 203, height: 269)
        AppearancePreference.shared.quickLookSize = invalidSize

        XCTAssertEqual(
            AppearancePreference.shared.quickLookSize,
            invalidSize,
            "Invalid size should be persisted before controller load"
        )

        let controller = PreviewViewController()
        controller.loadView()

        XCTAssertNil(
            AppearancePreference.shared.quickLookSize,
            "Invalid persisted size should be auto-cleared to nil after controller load"
        )
    }

    func testAutoClearIntegration_ValidPersistedSizeNotClearedOnViewControllerLoad() {
        let originalSize = AppearancePreference.shared.quickLookSize
        defer {
            AppearancePreference.shared.quickLookSize = originalSize
        }

        let validSize = CGSize(width: 800, height: 600)
        AppearancePreference.shared.quickLookSize = validSize

        XCTAssertEqual(
            AppearancePreference.shared.quickLookSize,
            validSize,
            "Valid size should be persisted before controller load"
        )

        let controller = PreviewViewController()
        controller.loadView()

        XCTAssertEqual(
            AppearancePreference.shared.quickLookSize,
            validSize,
            "Valid persisted size should NOT be cleared after controller load"
        )
    }
}
