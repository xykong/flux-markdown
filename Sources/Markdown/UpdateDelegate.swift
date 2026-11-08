import Cocoa
import Sparkle
import os.log

class UpdateDelegate: NSObject, SPUUpdaterDelegate {
    static let shared = UpdateDelegate()
    private let diagnostics: UpdateDiagnostics
    private(set) var targetVersion: String?
    private let clearPending: () -> Void

    init(diagnostics: UpdateDiagnostics = .shared,
         clearPending: @escaping () -> Void = { UpdateRestorationManager.shared.clearUpdatePending() }) {
        self.diagnostics = diagnostics
        self.clearPending = clearPending
        super.init()
    }

    func updater(_: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        targetVersion = nil
        diagnostics.beginSession()
    }

    func updater(_: SPUUpdater, didFinishLoading appcast: SUAppcast) { diagnostics.event(.appcastLoaded) }
    func updater(_: SPUUpdater, willDownloadUpdate item: SUAppcastItem, with request: NSMutableURLRequest) { diagnostics.event(.downloadStarted) }
    func updater(_: SPUUpdater, didDownloadUpdate item: SUAppcastItem) { diagnostics.event(.downloadCompleted) }
    func updater(_: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) { diagnostics.event(.downloadFailed) }
    func userDidCancelDownload(_: SPUUpdater) { diagnostics.event(.cancelled) }
    func updater(_: SPUUpdater, willExtractUpdate item: SUAppcastItem) { diagnostics.event(.extractionStarted) }
    func updater(_: SPUUpdater, didExtractUpdate item: SUAppcastItem) { diagnostics.event(.extractionCompleted) }

    func updater(_: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        diagnostics.event(.installHandoff)
        UpdateRestorationManager.shared.markUpdatePending()
    }

    func updater(_: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        targetVersion = item.displayVersionString
        diagnostics.event(.updateFound)
    }

    func updater(_: SPUUpdater, didAbortWithError error: Error) {
        clearPending()
        let nsError = error as NSError
        // Sparkle reports these normal outcomes through the same callback.
        guard !(nsError.domain == "SUSparkleErrorDomain" && [1001, 4007].contains(nsError.code)) else {
            diagnostics.event(nsError.code == 1001 ? .noUpdate : .cancelled)
            return
        }
        diagnostics.freeze(error: error)
        diagnostics.record(error: error,
                                        sourceVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
                                        targetVersion: targetVersion)
        os_log("Update aborted: %{public}@", log: OSLog(subsystem: "com.markdownquicklook.app", category: "Updater"),
               type: .error, diagnostics.summary())
    }

    func updater(_: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        diagnostics.event(.cycleFinished)
        targetVersion = nil
    }
}
