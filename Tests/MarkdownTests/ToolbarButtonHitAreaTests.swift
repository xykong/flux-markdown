import XCTest

final class ToolbarButtonHitAreaTests: XCTestCase {
    func testFloatingToolbarButtonsUseAppKitBoundsBasedHitControls() throws {
        let toolbarSourcePath = try projectRoot().appendingPathComponent("Sources/Markdown/MarkdownApp.swift").path
        let source = try String(contentsOfFile: toolbarSourcePath, encoding: .utf8)
        let toolbarRange = try XCTUnwrap(
            source.range(of: "HStack(spacing: 8) {"),
            "Floating toolbar HStack should exist"
        )
        let toolbarSource = String(source[toolbarRange.lowerBound...])
        let toolbarEndRange = try XCTUnwrap(
            toolbarSource.range(of: "                .padding([.top, .trailing], 10)"),
            "Floating toolbar should end at its top/trailing padding"
        )
        let floatingToolbarSource = String(toolbarSource[..<toolbarEndRange.lowerBound])

        let helperRange = try XCTUnwrap(
            source.range(of: "private struct ToolbarIconButton: View"),
            "Floating toolbar buttons should use a shared helper so hit-area modifiers cannot drift per button"
        )
        let helperSource = String(source[helperRange.lowerBound...])

        XCTAssertEqual(
            floatingToolbarSource.components(separatedBy: "ToolbarIconButton(").count - 1,
            7,
            "Every visible circular toolbar control should use the shared AppKit-backed hit-area helper."
        )
        XCTAssertTrue(
            helperSource.contains("NSViewRepresentable")
                && helperSource.contains("NSButton")
                && helperSource.contains("ToolbarIconNSButton"),
            "SwiftUI-only hit expansion failed over WKWebView; toolbar buttons need an AppKit-backed 30x30 control with bounds-based hit testing."
        )
        XCTAssertTrue(
            helperSource.contains("override func hitTest(_ point: NSPoint) -> NSView?")
                && helperSource.contains("bounds.contains(point) ? self : nil"),
            "The AppKit control must explicitly claim every point inside its 30x30 bounds so perimeter clicks cannot pass through to the web view."
        )
        XCTAssertTrue(
            helperSource.contains("NSImage(systemSymbolName: systemName")
                && helperSource.contains(".frame(width: 30, height: 30)")
                && helperSource.contains("NSBezierPath(ovalIn: bounds).fill()"),
            "The helper must keep the same 30x30 circular visual while moving real hit testing to AppKit bounds."
        )
        XCTAssertTrue(
            helperSource.contains("override var isHighlighted: Bool")
                && helperSource.contains("needsDisplay = true")
                && helperSource.contains("isHighlighted ?")
                && helperSource.contains("NSColor.controlAccentColor")
                && helperSource.contains("imageRect(forBounds:")
                && helperSource.contains("image.draw(in: imageRect(forBounds: bounds))"),
            "Floating toolbar buttons should redraw their circular background and icon in a visible pressed-state highlight."
        )

        let notificationSourcePath = try projectRoot().appendingPathComponent("Sources/Shared/NotificationNames.swift").path
        let notificationSource = try String(contentsOfFile: notificationSourcePath, encoding: .utf8)
        XCTAssertTrue(
            notificationSource.contains("static let reloadFileSucceeded")
                && notificationSource.contains("static let reloadFileFailed"),
            "Manual reload should publish success/failure notifications so native UI can show a visible tip."
        )

        let webViewSourcePath = try projectRoot().appendingPathComponent("Sources/Markdown/MarkdownWebView.swift").path
        let webViewSource = try String(contentsOfFile: webViewSourcePath, encoding: .utf8)
        XCTAssertTrue(
            webViewSource.contains("@discardableResult")
                && webViewSource.contains("private func reloadFromDisk(url: URL) -> Bool"),
            "Reload should return a success flag so manual reload can show accurate feedback."
        )
        XCTAssertTrue(
            webViewSource.contains("NotificationCenter.default.post(name: .reloadFileSucceeded")
                && webViewSource.contains("NotificationCenter.default.post(name: .reloadFileFailed")
                && webViewSource.contains("object: window"),
            "Manual reload must publish success or failure scoped to the originating document window for the native toast."
        )
        XCTAssertTrue(
            webViewSource.contains("window.isKeyWindow || window.windowController?.document === NSDocumentController.shared.currentDocument"),
            "Manual reload must only be handled by the active/current document window so one reload cannot affect every open document."
        )
        XCTAssertTrue(
            source.contains("ReloadToast")
                && source.contains("@State private var reloadToastMessage")
                && source.contains("ReloadToastObserver")
                && source.contains("ReloadToastNotificationRouter")
                && source.contains("NSLog(\"✅ Reload toast requested: %@\", message)"),
            "Document view should show and log a native toast only for reload results from its own window."
        )

        let routerSourcePath = try projectRoot().appendingPathComponent("Sources/Shared/ReloadToastNotificationRouter.swift").path
        let routerSource = try String(contentsOfFile: routerSourcePath, encoding: .utf8)
        XCTAssertTrue(
            routerSource.contains("center.addObserver(forName: .reloadFileSucceeded, object: window")
                && routerSource.contains("center.addObserver(forName: .reloadFileFailed, object: window"),
            "Reload toast notification routing should listen only to notifications posted by its own document window."
        )
        XCTAssertTrue(
            source.contains("已重新载入文档")
                && source.contains("重新载入失败"),
            "Reload toast should include clear Chinese success/failure messages."
        )
    }

    func testReloadToastNotificationRouterOnlyHandlesItsOwnWindow() {
        let owningWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 200), styleMask: [], backing: .buffered, defer: false)
        let otherWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 200), styleMask: [], backing: .buffered, defer: false)
        var results: [ReloadToastResult] = []
        let router = ReloadToastNotificationRouter { results.append($0) }

        router.monitor(window: owningWindow)
        NotificationCenter.default.post(name: .reloadFileSucceeded, object: otherWindow)
        NotificationCenter.default.post(name: .reloadFileFailed, object: otherWindow)
        XCTAssertTrue(results.isEmpty, "Reload toast routing should ignore other document windows.")

        NotificationCenter.default.post(name: .reloadFileSucceeded, object: owningWindow)
        NotificationCenter.default.post(name: .reloadFileFailed, object: owningWindow)
        XCTAssertEqual(results, [.success, .failure])
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
