import XCTest
import AppKit
import SwiftUI

final class ToolbarButtonHitAreaTests: XCTestCase {
    func testMainAppAndQuickLookUseSharedNativeCircularToolbarButtons() throws {
        let root = try projectRoot()
        let sharedSourcePath = root.appendingPathComponent("Sources/Shared/CircularToolbarButton.swift").path
        let mainAppSourcePath = root.appendingPathComponent("Sources/Markdown/MarkdownApp.swift").path
        let quickLookSourcePath = root.appendingPathComponent("Sources/MarkdownPreview/PreviewViewController.swift").path

        let sharedSource = try String(contentsOfFile: sharedSourcePath, encoding: .utf8)
        let mainAppSource = try String(contentsOfFile: mainAppSourcePath, encoding: .utf8)
        let quickLookSource = try String(contentsOfFile: quickLookSourcePath, encoding: .utf8)

        XCTAssertTrue(
            sharedSource.contains("final class CircularToolbarButton: NSButton")
                && sharedSource.contains("bezelStyle = .circular")
                && sharedSource.contains("isBordered = true"),
            "Toolbar controls should use a shared native AppKit circular NSButton instead of custom oval drawing."
        )
        XCTAssertTrue(
            sharedSource.contains("override func hitTest(_ point: NSPoint) -> NSView?")
                && sharedSource.contains("let localPoint = superview.map { convert(point, from: $0) } ?? point")
                && sharedSource.contains("bounds.contains(localPoint) ? self : nil")
                && sharedSource.contains("NSSize(width: 30, height: 30)"),
            "The shared native button must convert AppKit's superview-coordinate hit-test point before checking its 30x30 bounds."
        )
        XCTAssertFalse(
            sharedSource.contains("NSBezierPath(ovalIn:")
                || sharedSource.contains("button.layer?.cornerRadius")
                || sharedSource.contains("button.layer?.backgroundColor"),
            "Native circular toolbar buttons should not depend on custom oval drawing or layer background hacks."
        )

        XCTAssertEqual(
            mainAppSource.components(separatedBy: "CircularToolbarIconButton(").count - 1,
            7,
            "Every main app floating toolbar control should use the SwiftUI wrapper for the shared native button."
        )
        XCTAssertFalse(
            mainAppSource.contains("ToolbarIconNSButton") || mainAppSource.contains("NSBezierPath(ovalIn:"),
            "The main app must not keep the old custom-drawn square-bezel toolbar button."
        )

        XCTAssertEqual(
            quickLookSource.components(separatedBy: "CircularToolbarButton.make(").count - 1,
            7,
            "Every QuickLook toolbar control should be created through the shared native circular button factory."
        )
        XCTAssertFalse(
            quickLookSource.contains("button.layer?.cornerRadius = 15")
                || quickLookSource.contains("button.layer?.backgroundColor"),
            "QuickLook toolbar buttons should not use layer-rounded translucent rectangles for circular visuals."
        )
    }

    func testCircularToolbarButtonsRegisterFullBoundsToolTips() throws {
        let root = try projectRoot()
        let sharedSourcePath = root.appendingPathComponent("Sources/Shared/CircularToolbarButton.swift").path
        let mainAppSourcePath = root.appendingPathComponent("Sources/Markdown/MarkdownApp.swift").path
        let quickLookSourcePath = root.appendingPathComponent("Sources/MarkdownPreview/PreviewViewController.swift").path

        let sharedSource = try String(contentsOfFile: sharedSourcePath, encoding: .utf8)
        let mainAppSource = try String(contentsOfFile: mainAppSourcePath, encoding: .utf8)
        let quickLookSource = try String(contentsOfFile: quickLookSourcePath, encoding: .utf8)

        XCTAssertTrue(
            sharedSource.contains("addToolTip(bounds, owner: self, userData: nil)")
                && sharedSource.contains("removeToolTip")
                && sharedSource.contains("func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag"),
            "Small AppKit toolbar buttons should explicitly register a full-bounds tooltip rect so hover tips survive SwiftUI/QuickLook embedding."
        )
        XCTAssertTrue(
            mainAppSource.contains("Reload File (⌘R)")
                && mainAppSource.contains("Reset Zoom (⌘0)"),
            "Main app refresh and reset zoom controls should keep their user-facing tooltip text."
        )
        XCTAssertTrue(
            quickLookSource.contains("toolTip: \"Reload File (⌘R)\"")
                && quickLookSource.contains("toolTip: \"Reset Zoom (⌘0)\""),
            "QuickLook refresh and reset zoom controls should keep explicit user-facing tooltip text."
        )
    }

    func testMainAppToolbarButtonsReceiveTheSelectedPreviewAppearance() throws {
        // GIVEN the selected preview appearance can differ from the host window.
        let root = try projectRoot()
        let mainAppSourcePath = root.appendingPathComponent("Sources/Markdown/MarkdownApp.swift").path
        let mainAppSource = try String(contentsOfFile: mainAppSourcePath, encoding: .utf8)

        // WHEN the seven floating toolbar buttons are constructed.
        let appearanceBindings = mainAppSource
            .components(separatedBy: "appearance: preference.currentMode.nsAppearance")
            .count - 1

        // THEN every button must receive the same explicit appearance as the preview.
        XCTAssertEqual(
            appearanceBindings,
            7,
            "Every main app toolbar button must resolve its native colors against the selected preview appearance, not an unrelated host appearance."
        )
    }

    func testCircularToolbarButtonResolvesLabelTintAgainstExplicitAppearance() {
        // GIVEN SwiftUI bridges its dynamic label color while the host is Dark.
        let target = ToolbarButtonTarget()
        var bridgedLabelColor: NSColor?
        NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance {
            bridgedLabelColor = NSColor(Color(NSColor.labelColor))
        }

        // AND a native toolbar button renders that color for an explicitly Light preview.
        let lightAppearance = NSAppearance(named: .aqua)
        let button = CircularToolbarButton.make(
            systemName: "arrow.clockwise",
            accessibilityDescription: "Reload File",
            tintColor: bridgedLabelColor ?? .labelColor,
            target: target,
            action: #selector(ToolbarButtonTarget.performAction),
            toolTip: "Reload File",
            appearance: lightAppearance
        )

        // WHEN AppKit resolves the dynamic label color for that button.
        var resolvedTint: NSColor?
        button.effectiveAppearance.performAsCurrentDrawingAppearance {
            resolvedTint = button.contentTintColor?.usingColorSpace(NSColorSpace.deviceRGB)
        }

        // THEN the button uses Aqua and produces a dark foreground for contrast.
        XCTAssertEqual(button.appearance?.name, .aqua)
        XCTAssertNotNil(resolvedTint)
        XCTAssertLessThan(
            resolvedTint?.brightnessComponent ?? 1,
            0.5,
            "A label-colored icon over a Light preview must resolve to a dark foreground."
        )

        // GIVEN the same button is updated for an explicitly dark preview.
        button.appearance = NSAppearance(named: .darkAqua)
        button.configure(
            systemName: "arrow.clockwise",
            accessibilityDescription: "Reload File",
            tintColor: bridgedLabelColor ?? .labelColor,
            toolTip: "Reload File"
        )

        // WHEN AppKit resolves the dynamic label color again.
        button.effectiveAppearance.performAsCurrentDrawingAppearance {
            resolvedTint = button.contentTintColor?.usingColorSpace(NSColorSpace.deviceRGB)
        }

        // THEN it produces a light foreground for contrast.
        XCTAssertEqual(button.appearance?.name, .darkAqua)
        XCTAssertGreaterThan(
            resolvedTint?.brightnessComponent ?? 0,
            0.5,
            "A label-colored icon over a Dark preview must resolve to a light foreground."
        )
    }

    func testCircularToolbarButtonExposesTooltipOwnerSelectorToAppKit() throws {
        let target = ToolbarButtonTarget()
        let button = CircularToolbarButton.make(
            systemName: "arrow.clockwise",
            accessibilityDescription: "Reload File",
            tintColor: .labelColor,
            target: target,
            action: #selector(ToolbarButtonTarget.performAction),
            toolTip: "Reload File (⌘R)"
        )

        let selector = NSSelectorFromString("view:stringForToolTip:point:userData:")
        XCTAssertTrue(
            button.responds(to: selector),
            "AppKit asks tooltip owners for text through the Objective-C selector view:stringForToolTip:point:userData:; the circular toolbar button must expose that selector at runtime."
        )
        XCTAssertNil(
            button.toolTip,
            "Circular toolbar buttons should not register both NSButton.toolTip and addToolTip over the same bounds; overlapping AppKit tooltip registrations make hover tips unreliable."
        )
    }

    func testCircularToolbarButtonHitTestingWorksWhenOffsetInQuickLookToolbar() {
        let target = ToolbarButtonTarget()
        let button = CircularToolbarButton.make(
            systemName: "arrow.clockwise",
            accessibilityDescription: "Reload File",
            tintColor: .labelColor,
            target: target,
            action: #selector(ToolbarButtonTarget.performAction),
            toolTip: "Reload File (⌘R)"
        )
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 160))
        button.frame = NSRect(x: 160, y: 100, width: 30, height: 30)
        container.addSubview(button)

        XCTAssertIdentical(
            button.hitTest(NSPoint(x: 175, y: 115)),
            button,
            "QuickLook adds toolbar buttons directly to an offset position in the root view; AppKit passes hit-test points in the superview coordinate space, so the button must convert before checking bounds."
        )
        XCTAssertNil(
            button.hitTest(NSPoint(x: 210, y: 115)),
            "Points outside the offset button frame should still pass through to the underlying QuickLook web view."
        )
    }

    func testToolbarButtonsUseExistingToastFeedbackInsteadOfCustomHoverOverlay() throws {
        let root = try projectRoot()
        let sharedSourcePath = root.appendingPathComponent("Sources/Shared/CircularToolbarButton.swift").path
        let notificationSourcePath = root.appendingPathComponent("Sources/Shared/NotificationNames.swift").path
        let routerSourcePath = root.appendingPathComponent("Sources/Shared/ToolbarFeedbackNotificationRouter.swift").path
        let mainAppSourcePath = root.appendingPathComponent("Sources/Markdown/MarkdownApp.swift").path
        let mainWebViewSourcePath = root.appendingPathComponent("Sources/Markdown/MarkdownWebView.swift").path
        let quickLookSourcePath = root.appendingPathComponent("Sources/MarkdownPreview/PreviewViewController.swift").path

        let sharedSource = try String(contentsOfFile: sharedSourcePath, encoding: .utf8)
        let notificationSource = try String(contentsOfFile: notificationSourcePath, encoding: .utf8)
        let mainAppSource = try String(contentsOfFile: mainAppSourcePath, encoding: .utf8)
        let mainWebViewSource = try String(contentsOfFile: mainWebViewSourcePath, encoding: .utf8)
        let quickLookSource = try String(contentsOfFile: quickLookSourcePath, encoding: .utf8)

        XCTAssertFalse(
            sharedSource.contains("hoverTipView")
                || sharedSource.contains("NSTrackingArea")
                || sharedSource.contains("override func mouseEntered(with event: NSEvent)")
                || sharedSource.contains("override func mouseExited(with event: NSEvent)"),
            "Toolbar button hover text should use AppKit tooltip registration plus the existing toast feedback system, not a second custom hover overlay."
        )
        XCTAssertTrue(
            notificationSource.contains("static let reloadFileSucceeded")
                && notificationSource.contains("static let reloadFileFailed")
                && notificationSource.contains("static let resetZoomCompleted"),
            "Toolbar actions should publish scoped feedback notifications so the owning native window can show visible tips."
        )

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: routerSourcePath),
            "Toolbar feedback should reuse the existing window-scoped toast routing pattern in a shared router."
        )
        if FileManager.default.fileExists(atPath: routerSourcePath) {
            let routerSource = try String(contentsOfFile: routerSourcePath, encoding: .utf8)
            XCTAssertTrue(
                routerSource.contains("enum ToolbarFeedbackResult")
                    && routerSource.contains("final class ToolbarFeedbackNotificationRouter")
                    && routerSource.contains("center.addObserver(forName: .reloadFileSucceeded, object: window")
                    && routerSource.contains("center.addObserver(forName: .reloadFileFailed, object: window")
                    && routerSource.contains("center.addObserver(forName: .resetZoomCompleted, object: window"),
                "Toolbar feedback routing should listen only to notifications posted by its own document window."
            )
        }

        XCTAssertTrue(
            mainAppSource.contains("ToolbarFeedbackToastHost")
                && mainAppSource.contains("@State private var toolbarToast")
                && mainAppSource.contains("ToolbarFeedbackObserver")
                && mainAppSource.contains("ToolbarFeedbackNotificationRouter")
                && mainAppSource.contains("已重新载入文档")
                && mainAppSource.contains("重新载入失败")
                && mainAppSource.contains("已重置缩放"),
            "Main document windows should show the existing native toast feedback for reload success/failure and reset zoom."
        )
        XCTAssertTrue(
            mainWebViewSource.contains("private func reloadFromDisk(url: URL, force: Bool = false) -> Bool")
                && mainWebViewSource.contains("NotificationCenter.default.post(name: .reloadFileSucceeded, object: window)")
                && mainWebViewSource.contains("NotificationCenter.default.post(name: .reloadFileFailed, object: window)")
                && mainWebViewSource.contains("NotificationCenter.default.post(name: .resetZoomCompleted, object: window)"),
            "Main WebView toolbar commands should report visible feedback through window-scoped notifications."
        )
        XCTAssertTrue(
            quickLookSource.contains("showToolbarFeedbackToast")
                && quickLookSource.contains("showToast(")
                && quickLookSource.contains("if reloadFromDisk(force: true)")
                && quickLookSource.contains("已重新载入文档")
                && quickLookSource.contains("重新载入失败")
                && quickLookSource.contains("已重置缩放"),
            "QuickLook should reuse its existing native toast container for reload and reset-zoom tips."
        )
    }

    func testMainAppToolbarFeedbackUsesAppKitToastHostAboveWebView() throws {
        let root = try projectRoot()
        let mainAppSourcePath = root.appendingPathComponent("Sources/Markdown/MarkdownApp.swift").path
        let mainAppSource = try String(contentsOfFile: mainAppSourcePath, encoding: .utf8)

        XCTAssertTrue(
            mainAppSource.contains("ToolbarFeedbackToastHost")
                && mainAppSource.contains("NSViewRepresentable")
                && mainAppSource.contains("ToolbarFeedbackToastHostView: NSView")
                && mainAppSource.contains("override func hitTest(_ point: NSPoint) -> NSView? { nil }"),
            "Main app toolbar feedback must be rendered through an AppKit passthrough host above WKWebView; SwiftUI-only text overlays can be hidden behind WKWebView."
        )
        XCTAssertFalse(
            mainAppSource.contains("ToolbarFeedbackToast(message: toolbarToastMessage)"),
            "The runtime-visible toast should not depend on the previous SwiftUI-only Text overlay."
        )
    }

    func testMainAppToolbarFeedbackUsesHistoricalUpperCenterPlacementAndStyle() throws {
        let root = try projectRoot()
        let mainAppSourcePath = root.appendingPathComponent("Sources/Markdown/MarkdownApp.swift").path
        let mainAppSource = try String(contentsOfFile: mainAppSourcePath, encoding: .utf8)

        XCTAssertTrue(
            mainAppSource.contains("toastContainer.topAnchor.constraint(equalTo: topAnchor, constant: 52)")
                && mainAppSource.contains("toastContainer.centerXAnchor.constraint(equalTo: centerXAnchor)"),
            "Main app toolbar tips should match the historical upper-center placement, not top-right placement."
        )
        XCTAssertFalse(
            mainAppSource.contains("toastContainer.trailingAnchor.constraint(equalTo: trailingAnchor"),
            "Toolbar feedback tips must not be anchored to the right edge."
        )
        XCTAssertTrue(
            mainAppSource.contains("private final class ToolbarToastContainerView: NSView")
                && mainAppSource.contains("let toastContainer = ToolbarToastContainerView()")
                && mainAppSource.contains("layerContentsRedrawPolicy = .onSetNeedsDisplay")
                && mainAppSource.contains("override func layout()")
                && mainAppSource.contains("layer.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.97).cgColor")
                && mainAppSource.contains("cornerRadius = 12")
                && mainAppSource.contains("layer.masksToBounds = false")
                && mainAppSource.contains("layer.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor")
                && mainAppSource.contains("layer.shadowRadius = 10")
                && mainAppSource.contains("layer.shadowPath = CGPath(roundedRect: bounds")
                && mainAppSource.contains("messageLabel.textColor = .labelColor"),
            "Main app toolbar tips should keep the historical light native rounded style instead of the QuickLook accent-color banner style."
        )
        XCTAssertFalse(
            mainAppSource.contains("toastContainer.layer = ToolbarToastLayer()"),
            "Toast styling should use an AppKit-managed layer-backed view; directly replacing the backing layer can leave the rounded card undrawn while text still appears."
        )
    }

    func testMainAppToolbarOutcomeToastsKeepImmediateHistoricalFeedback() throws {
        let root = try projectRoot()
        let mainAppSourcePath = root.appendingPathComponent("Sources/Markdown/MarkdownApp.swift").path
        let mainAppSource = try String(contentsOfFile: mainAppSourcePath, encoding: .utf8)

        XCTAssertEqual(
            mainAppSource.components(separatedBy: "showToolbarToast(reloadSuccessToastMessage)").count - 1,
            2,
            "Reload should keep the historical immediate visible feedback and still handle the scoped reload success notification."
        )
        XCTAssertEqual(
            mainAppSource.components(separatedBy: "showToolbarToast(resetZoomToastMessage)").count - 1,
            2,
            "Reset zoom should show immediate toolbar feedback and still handle the scoped completion notification."
        )
    }

    func testMainAppToolbarToastDismissalUsesStableIdentity() throws {
        let root = try projectRoot()
        let mainAppSourcePath = root.appendingPathComponent("Sources/Markdown/MarkdownApp.swift").path
        let mainAppSource = try String(contentsOfFile: mainAppSourcePath, encoding: .utf8)

        XCTAssertTrue(
            mainAppSource.contains("struct ToolbarToastState: Equatable")
                && mainAppSource.contains("let id: UUID")
                && mainAppSource.contains("if toolbarToast?.id == id"),
            "Repeated identical toolbar toast messages need a stable per-toast identity so an older dismissal cannot clear a newer toast."
        )
        XCTAssertFalse(
            mainAppSource.contains("if toolbarToastMessage == message"),
            "Message equality is not safe for dismissing repeated identical toolbar toasts."
        )
    }

    func testToolbarFeedbackNotificationRouterOnlyHandlesItsOwnWindow() {
        let owningWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 200), styleMask: [], backing: .buffered, defer: false)
        let otherWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 200), styleMask: [], backing: .buffered, defer: false)
        var results: [ToolbarFeedbackResult] = []
        let router = ToolbarFeedbackNotificationRouter { results.append($0) }

        router.monitor(window: owningWindow)
        NotificationCenter.default.post(name: .reloadFileSucceeded, object: otherWindow)
        NotificationCenter.default.post(name: .reloadFileFailed, object: otherWindow)
        NotificationCenter.default.post(name: .resetZoomCompleted, object: otherWindow)
        XCTAssertTrue(results.isEmpty, "Toolbar feedback routing should ignore other document windows.")

        NotificationCenter.default.post(name: .reloadFileSucceeded, object: owningWindow)
        NotificationCenter.default.post(name: .reloadFileFailed, object: owningWindow)
        NotificationCenter.default.post(name: .resetZoomCompleted, object: owningWindow)
        XCTAssertEqual(results, [.reloadSuccess, .reloadFailure, .resetZoom])
    }

    private func projectRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath)
        while directory.path != "/" {
            let candidate = directory.appendingPathComponent("project.yml")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return directory
            }
            directory.deleteLastPathComponent()
        }
        throw NSError(domain: "ToolbarButtonHitAreaTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not locate project root from \(#filePath)"])
    }
}

private final class ToolbarButtonTarget: NSObject {
    @objc func performAction() {}
}
