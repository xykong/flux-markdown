import AppKit

/// Host-only user confirmation. A claim never records a document open or reading time.
final class PromotionAttributionController {
    static let shared = PromotionAttributionController()
    private var generation = UUID()
    private weak var confirmation: NSAlert?
    private var observer: NSObjectProtocol?
    private lazy var client = PromotionClaimClient(installation: Self.currentInstallation,
        clientVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0")
    private init() {
        observer = NotificationCenter.default.addObserver(forName: UsageTelemetry.settingsChanged, object: nil, queue: .main) { [weak self] _ in
            guard let self, !UsageTelemetry.shared.enabled else { return }
            self.generation = UUID(); self.client.cancel()
            if let alert = self.confirmation, NSApp.modalWindow === alert.window { NSApp.abortModal() }
        }
    }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    private static func currentInstallation() -> String? {
        UsageTelemetry.shared.transaction { state -> String? in state.enabled ? state.installationID : nil } ?? nil
    }
    @discardableResult func receive(_ url: URL) -> Bool {
        guard PromotionClaimRequest.handles(url) else { return false }
        let request = PromotionClaimRequest(url: url)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let request else { self.showFailure(.invalidLink, retry: nil); return }
            self.generation = UUID(); let generation = self.generation
            self.client.cancel()
            guard let installation = Self.currentInstallation() else {
                let alert=NSAlert();alert.messageText=ErrorFeedback.text("Usage Statistics Are Off")
                alert.informativeText=ErrorFeedback.text("No promotion source will be shared. You can keep using FluxMarkdown with statistics turned off.")
                alert.addButton(withTitle:ErrorFeedback.text("Close"));alert.runModal();return
            }
            let alert=NSAlert();self.confirmation=alert
            alert.messageText=ErrorFeedback.text("Share This Promotion Source?")
            alert.informativeText=ErrorFeedback.text("Link this promotion to your random installation identifier to help measure its effectiveness. No document information is sent. This is optional and does not count as reading activity.")
            alert.addButton(withTitle:ErrorFeedback.text("Share Source"))
            alert.addButton(withTitle:ErrorFeedback.text("Not Now"))
            NSApp.activate(ignoringOtherApps:true)
            let response=alert.runModal();self.confirmation=nil
            guard response == .alertFirstButtonReturn, self.generation == generation else {return}
            self.send(request,installation:installation,generation:generation)
        }
        return true
    }
    private func send(_ request: PromotionClaimRequest, installation: String, generation: UUID) {
        guard self.generation==generation else{return}
        client.redeem(request,installationID:installation){[weak self] result in
            guard let self,self.generation==generation else{return}
            switch result {
            case .success:
                let alert=NSAlert();alert.messageText=ErrorFeedback.text("Promotion Source Linked")
                alert.informativeText=ErrorFeedback.text("Thank you. The source is linked to this installation. Effective use and return visits are measured separately when usage statistics are enabled.")
                alert.addButton(withTitle:ErrorFeedback.text("Close"));alert.runModal()
            case .failure(let error):
                if [.cancelled,.disabled,.identityChanged].contains(error){return}
                let retry:(()->Void)? = [.network,.service].contains(error) && Date().timeIntervalSince(request.receivedAt)<600 ? { [weak self] in self?.send(request,installation:installation,generation:generation) } : nil
                self.showFailure(error,retry:retry)
            }
        }
    }
    private func showFailure(_ error: PromotionClaimError, retry: (() -> Void)?) {
        let incident=ErrorFeedback.capture(.attribution,error:error,reason:error == .invalidLink ? .invalidInput : .operationFailed)
        ErrorFeedback.present(incident,recoveryTitle:retry == nil ? "Open Promotion Page" : "Try Again",recovery:retry ?? {
            if !NSWorkspace.shared.open(PromotionClaimClient.promotionPage) {
                let failed=ErrorFeedback.capture(.browser)
                ErrorFeedback.present(failed,recoveryTitle:"Copy Link",recovery:{
                    NSPasteboard.general.clearContents();NSPasteboard.general.setString(PromotionClaimClient.promotionPage.absoluteString,forType:.string)
                })
            }
        })
    }
}
