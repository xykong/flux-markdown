#if canImport(Sparkle)
import XCTest
import Sparkle

final class UpdateErrorPresentationTests: XCTestCase {
    func testPublicStageSelectorsAndFrozenPresentationHistory() throws {
        let delegate = UpdateDelegate.shared
        for selector in ["updater:mayPerformUpdateCheck:error:", "updater:didFinishLoadingAppcast:",
                         "updater:willDownloadUpdate:withRequest:", "updater:didDownloadUpdate:",
                         "updater:failedToDownloadUpdate:error:", "userDidCancelDownload:",
                         "updater:willExtractUpdate:", "updater:didExtractUpdate:"] {
            XCTAssertTrue(delegate.responds(to: NSSelectorFromString(selector)), selector)
        }
        UpdateDiagnostics.shared.beginSession()
        UpdateDiagnostics.shared.event(.downloadCompleted)
        let driver = UpdateErrorUserDriver(presentAlert: { _ in
            UpdateDiagnostics.shared.event(.cycleFinished)
            return .alertSecondButtonReturn
        }, reportIncident: { draft in
            XCTAssertEqual(draft.incident.updateSession?.events.map(\.stage), [.checkStarted, .downloadCompleted, .failed])
            XCTAssertTrue(draft.incident.isValid)
        })
        driver.showUpdaterError(NSError(domain: "SUSparkleErrorDomain", code: 4005)) {
            UpdateDiagnostics.shared.beginSession()
        }
    }

    func testDownloadActionShowsRecoveryAndAcknowledgesOnce() {
        var opened: URL?
        var acknowledgements = 0
        let driver = UpdateErrorUserDriver(presentAlert: { alert in
            XCTAssertEqual(alert.messageText, "Could Not Update FluxMarkdown")
            XCTAssertTrue(alert.informativeText.contains("download"))
            XCTAssertTrue(alert.informativeText.contains("manually"))
            XCTAssertEqual(alert.buttons.map(\.title), ["Download Latest Version", "Report This Problem", "Close"])
            return .alertFirstButtonReturn
        }, openURL: { opened = $0; return true })
        driver.showUpdaterError(NSError(domain: "SUSparkleErrorDomain", code: 4005)) { acknowledgements += 1 }
        XCTAssertEqual(opened?.absoluteString, "https://github.com/xykong/flux-markdown/releases/latest")
        XCTAssertEqual(acknowledgements, 1)
    }

    func testReportCapturesFailureBeforeHandoffAndAcknowledgesFirst() {
        var actions: [String] = []
        let driver = UpdateErrorUserDriver(presentAlert: { _ in .alertSecondButtonReturn },
                                          openURL: { _ in XCTFail("Reporting must use its own route"); return false },
                                          reportIncident: { draft in
            actions.append("report")
            XCTAssertTrue(draft.incident.report.contains("SUSparkleErrorDomain:4005"))
            XCTAssertFalse(draft.incident.report.contains("private"))
        })
        driver.showUpdaterError(NSError(domain: "SUSparkleErrorDomain", code: 4005, userInfo: [NSLocalizedDescriptionKey: "private text"])) { actions.append("acknowledge") }
        XCTAssertEqual(actions, ["acknowledge", "report"])
    }

    func testCloseAcknowledgesWithoutOpeningBrowser() {
        var acknowledgements = 0
        let driver = UpdateErrorUserDriver(presentAlert: { _ in .alertThirdButtonReturn },
                                          openURL: { _ in XCTFail("Close must not open a website"); return false })
        driver.showUpdaterError(NSError(domain: "SUSparkleErrorDomain", code: 4005)) { acknowledgements += 1 }
        XCTAssertEqual(acknowledgements, 1)
    }

    func testBrowserFailureOffersCopyableDownloadURL() {
        var alerts = 0
        let driver = UpdateErrorUserDriver(presentAlert: { alert in
            alerts += 1
            if alerts == 2 {
                XCTAssertEqual(alert.messageText, "Could Not Open Download Page")
                let field = alert.accessoryView as? NSTextField
                XCTAssertEqual(field?.stringValue, UpdateErrorUserDriver.downloadURL.absoluteString)
                XCTAssertEqual(field?.isSelectable, true)
            }
            return alerts == 1 ? .alertFirstButtonReturn : .alertSecondButtonReturn
        }, openURL: { _ in false })
        var acknowledgements = 0
        driver.showUpdaterError(NSError(domain: "SUSparkleErrorDomain", code: 4005)) { acknowledgements += 1 }
        XCTAssertEqual(alerts, 2)
        XCTAssertEqual(acknowledgements, 1)
    }

    func testActualSparkleAbortSelectorRecordsFailureButIgnoresNormalOutcomes() throws {
        let suite = "UpdateErrorPresentationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let diagnostics = UpdateDiagnostics(defaults: defaults)
        let delegate = UpdateDelegate(diagnostics: diagnostics, clearPending: {})
        XCTAssertTrue(delegate.responds(to: NSSelectorFromString("updater:didAbortWithError:")))
        XCTAssertTrue(delegate.responds(to: NSSelectorFromString("updater:didFinishUpdateCycleForUpdateCheck:error:")))
        let updater = SPUUpdater(hostBundle: .main, applicationBundle: .main,
                                userDriver: SPUStandardUserDriver(hostBundle: .main, delegate: nil), delegate: delegate)
        for code in [1001, 4007] {
            delegate.updater(updater, didAbortWithError: NSError(domain: "SUSparkleErrorDomain", code: code))
        }
        XCTAssertTrue(diagnostics.summary().contains("No recorded update failure"))
        delegate.updater(updater, didAbortWithError: NSError(domain: "SUSparkleErrorDomain", code: 4005))
        XCTAssertTrue(diagnostics.summary().contains("SUSparkleErrorDomain:4005"))
    }

    func testRealFailedCheckCanBeRepeatedAfterAcknowledgement() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let contents = root.appendingPathComponent("UpdateTest.app/Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let identifier = "com.xykong.UpdateTest.\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: identifier) }
        let info: [String: Any] = ["CFBundleIdentifier": identifier, "CFBundleName": "UpdateTest",
                                   "CFBundlePackageType": "APPL", "CFBundleVersion": "1", "CFBundleShortVersionString": "1.0",
                                   "SUFeedURL": "http://127.0.0.1:1/unavailable.xml", "SUEnableAutomaticChecks": false,
                                   "SUPublicEDKey": "BDhsLBTgtRax5K78RrmvkB2wCcLeKM7FxsuHu47soaU="]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        let bundle = try XCTUnwrap(Bundle(url: contents.deletingLastPathComponent()))
        var alerts = 0
        let driver = UpdateErrorUserDriver(hostBundle: bundle, presentAlert: { _ in
            alerts += 1
            return .alertThirdButtonReturn
        })
        let defaults = try XCTUnwrap(UserDefaults(suiteName: identifier))
        let diagnostics = UpdateDiagnostics(defaults: defaults)
        let delegate = UpdateDelegate(diagnostics: diagnostics, clearPending: {})
        let updater = SPUUpdater(hostBundle: bundle, applicationBundle: bundle, userDriver: driver, delegate: delegate)
        try updater.start()
        for expectedAlerts in 1...2 {
            updater.checkForUpdates()
            let deadline = Date().addingTimeInterval(10)
            while (alerts < expectedAlerts || !updater.canCheckForUpdates || diagnostics.summary().contains("No recorded update failure")), Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            }
            XCTAssertEqual(alerts, expectedAlerts)
            XCTAssertTrue(updater.canCheckForUpdates, "Acknowledgement must release the update cycle")
            XCTAssertFalse(diagnostics.summary().contains("No recorded update failure"), "Real Sparkle failures must reach the diagnostic delegate")
        }
        withExtendedLifetime(delegate) {}
    }
}
#endif
