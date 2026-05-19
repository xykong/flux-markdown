import XCTest

@MainActor
final class WindowSizePersistenceTests: XCTestCase {

    // MARK: - Host App Window Frame Tests

    func testHostDefaultFrame_UsesCurrentWidthAndEightyPercentVisibleHeight() {
        let visibleFrame = CGRect(x: 100, y: 50, width: 1440, height: 900)
        let currentFrame = CGRect(x: 0, y: 0, width: 1000, height: 480)

        let defaultFrame = WindowAccessor.defaultDocumentFrame(
            currentFrame: currentFrame,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(defaultFrame.width, 1000, "Default width should preserve current SwiftUI/window width")
        XCTAssertEqual(defaultFrame.height, 720, "Default height should leave 15% top and 5% bottom margins")
        XCTAssertEqual(defaultFrame.minY, 95, "Default y should leave a 5% bottom margin")
        XCTAssertEqual(defaultFrame.maxY, 815, "Default maxY should leave a 15% top margin")
        XCTAssertEqual(defaultFrame.midX, visibleFrame.midX, "Default frame should stay horizontally centered")
    }

    func testHostDefaultFrame_ClampsCurrentWidthToVisibleFrameWithoutChangingPolicy() {
        let visibleFrame = CGRect(x: -1200, y: 0, width: 900, height: 1000)
        let currentFrame = CGRect(x: 0, y: 0, width: 1200, height: 500)

        let defaultFrame = WindowAccessor.defaultDocumentFrame(
            currentFrame: currentFrame,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(defaultFrame.width, 900, "Default frame should not exceed the target screen width")
        XCTAssertEqual(defaultFrame.height, 800)
        XCTAssertEqual(defaultFrame.minX, visibleFrame.minX)
        XCTAssertEqual(defaultFrame.minY, 50)
    }

    func testHostFrameValidation_RejectsTinyAndNonFiniteFrames() {
        let invalidFrames = [
            CGRect(x: 0, y: 0, width: 203, height: 269),
            CGRect(x: 0, y: 0, width: 1000, height: 199),
            CGRect(x: 0, y: 0, width: 319, height: 800),
            CGRect(x: 0, y: 0, width: CGFloat.nan, height: 800),
            CGRect.null
        ]

        for frame in invalidFrames {
            XCTAssertFalse(
                WindowAccessor.isFrameValidForRestore(frame),
                "Frame \(frame) should be rejected for host window restore"
            )
        }
    }

    func testHostFrameValidation_AcceptsReasonableFrames() {
        let validFrame = CGRect(x: 120, y: 80, width: 1000, height: 720)

        XCTAssertTrue(WindowAccessor.isFrameValidForRestore(validFrame))
    }

    func testHostFrameRestorable_RejectsFramesOutsideCurrentScreens() {
        let savedFrame = CGRect(x: 2_000, y: 2_000, width: 1_000, height: 720)
        let currentScreens = [CGRect(x: 0, y: 0, width: 1440, height: 900)]

        XCTAssertFalse(
            WindowAccessor.isFrameRestorable(savedFrame, visibleFrames: currentScreens),
            "Saved frames from a disconnected monitor should be ignored and replaced with a default frame"
        )
    }

    func testHostFrameRestorable_AcceptsFramesWithUsableVisibleIntersection() {
        let savedFrame = CGRect(x: 1_100, y: 100, width: 1_000, height: 720)
        let currentScreens = [CGRect(x: 0, y: 0, width: 1_512, height: 949)]

        XCTAssertTrue(
            WindowAccessor.isFrameRestorable(savedFrame, visibleFrames: currentScreens),
            "A saved frame should restore when at least the minimum usable area is visible"
        )
    }

    func testHostFrameApplication_ReappliesDefaultWhenLaterWindowSizingOverwritesInitialFrame() {
        let visibleFrame = CGRect(x: 1_512, y: -98, width: 1_920, height: 1_080)
        let initialSwiftUIFrame = CGRect(x: 1_944, y: 397, width: 900, height: 450)
        let expectedDefaultFrame = WindowAccessor.defaultDocumentFrame(
            currentFrame: initialSwiftUIFrame,
            visibleFrame: visibleFrame
        )

        let actions = WindowAccessor.defaultFrameApplications(
            currentFrame: initialSwiftUIFrame,
            targetFrame: expectedDefaultFrame,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(actions.count, 3, "SwiftUI can overwrite early document frame passes; schedule bounded reapplies")
        XCTAssertEqual(actions[0].delay, 0)
        XCTAssertEqual(actions[0].frame, expectedDefaultFrame)
        XCTAssertNil(actions[0].expectedFrameBeforeApplication)
        XCTAssertEqual(actions[1].delay, 0.20)
        XCTAssertEqual(actions[1].frame, expectedDefaultFrame)
        XCTAssertEqual(actions[1].expectedFrameBeforeApplication, initialSwiftUIFrame)
        XCTAssertEqual(actions[2].delay, 0.80)
        XCTAssertEqual(actions[2].frame, expectedDefaultFrame)
        XCTAssertEqual(actions[2].expectedFrameBeforeApplication, initialSwiftUIFrame)
    }

    func testHostFrameApplication_DelayedReapplyOnlyTargetsOriginalSystemFrame() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1_512, height: 949)
        let initialSwiftUIFrame = CGRect(x: 306, y: 298, width: 900, height: 450)
        let expectedDefaultFrame = WindowAccessor.defaultDocumentFrame(
            currentFrame: initialSwiftUIFrame,
            visibleFrame: visibleFrame
        )

        let actions = WindowAccessor.defaultFrameApplications(
            currentFrame: initialSwiftUIFrame,
            targetFrame: expectedDefaultFrame,
            visibleFrame: visibleFrame
        )

        let delayedActions = actions.dropFirst()
        XCTAssertFalse(delayedActions.isEmpty)
        for action in delayedActions {
            XCTAssertEqual(
                action.expectedFrameBeforeApplication,
                initialSwiftUIFrame,
                "Delayed startup reapplies should only run if SwiftUI leaves the original startup frame intact"
            )
        }
    }

    func testHostFrameApplication_DoesNotLoopWhenWindowAlreadyMatchesTarget() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1_512, height: 949)
        let targetFrame = CGRect(x: 306, y: 47.45, width: 900, height: 759.2)

        let actions = WindowAccessor.defaultFrameApplications(
            currentFrame: targetFrame,
            targetFrame: targetFrame,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(actions.count, 1)
        XCTAssertEqual(actions[0].delay, 0)
        XCTAssertEqual(actions[0].frame, targetFrame)
    }

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
