import AppKit
import Foundation
import Security
import os.log

private let extensionURL = Bundle.main.bundleURL.deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
private let appURL = extensionURL.deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()

private func trustedPreview(_ connection: NSXPCConnection) -> Bool {
    guard connection.effectiveUserIdentifier == getuid(), connection.processIdentifier > 0 else { return false }
    var code: SecCode?
    let attributes = [kSecGuestAttributePid as String: NSNumber(value: connection.processIdentifier)] as CFDictionary
    guard SecCodeCopyGuestWithAttributes(nil, attributes, SecCSFlags(rawValue: 0), &code) == errSecSuccess,
          let code, SecCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate), nil) == errSecSuccess else { return false }
    var staticCode: SecStaticCode?
    guard SecCodeCopyStaticCode(code, SecCSFlags(rawValue: 0), &staticCode) == errSecSuccess,
          let staticCode else { return false }
    var info: CFDictionary?
    guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
          let dictionary = info as? [String: Any],
          let executable = dictionary[kSecCodeInfoMainExecutable as String] as? URL else { return false }
    let expected = extensionURL.appendingPathComponent("Contents/MacOS/MarkdownPreview")
    return SearchLaunchPolicy.acceptsPeer(sameUser: true, validSignature: true,
        identifier: dictionary[kSecCodeInfoIdentifier as String] as? String ?? "",
        expectedExecutable: executable.standardizedFileURL.resolvingSymlinksInPath() == expected.standardizedFileURL.resolvingSymlinksInPath())
}

private final class Launcher: NSObject, SearchLaunchServing {
    func flushUsage(reply: @escaping (Bool) -> Void) {
        UsageTelemetry.shared.flush(completion: reply)
    }
    func openDocument(_ value: String, reply: @escaping (Bool) -> Void) {
        guard value.utf8.count <= 8192, let url = URL(string: value), url.host == "open",
              let request = DocumentOpenRequest(url: url), !request.wantsSearch,
              let searchURL = DocumentOpenRequest.searchURL(for: request.fileURL), SearchLaunchPolicy.request(searchURL.absoluteString) != nil,
              Bundle(url: appURL)?.bundleIdentifier == "com.xykong.Markdown" else { reply(false); return }
        DispatchQueue.main.async {
            let configuration = NSWorkspace.OpenConfiguration(); configuration.activates = true; configuration.promptsUserIfNeeded = false
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration) { _, error in reply(error == nil) }
        }
    }
    func reportError(_ data: Data, reply: @escaping (Bool) -> Void) {
        guard let request = IncidentFeedbackRequest.decode(data), let url = request.hostURL,
              Bundle(url: appURL)?.bundleIdentifier == "com.xykong.Markdown" else { reply(false); return }
        DispatchQueue.main.async {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            configuration.promptsUserIfNeeded = false
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration) { _, error in reply(error == nil) }
        }
    }
    func openGitHubRepository(reply: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            reply(NSWorkspace.shared.open(URL(string: "https://github.com/xykong/flux-markdown")!))
        }
    }

    func openDocumentSearch(_ value: String, reply: @escaping (Bool) -> Void) {
        guard SearchLaunchPolicy.request(value) != nil, let url = URL(string: value),
              Bundle(url: appURL)?.bundleIdentifier == "com.xykong.Markdown" else { reply(false); return }
        DispatchQueue.main.async {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.promptsUserIfNeeded = false
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration) { _, error in
                if let error = error as NSError? {
                    os_log("Search broker launch failed (domain=%{public}@ code=%{public}ld)",
                        log: OSLog(subsystem: "com.markdownquicklook.app", category: "SearchLauncher"),
                        type: .error, error.domain, error.code)
                }
                reply(error == nil)
            }
        }
    }
}

private final class ServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard trustedPreview(connection) else { return false }
        connection.exportedInterface = NSXPCInterface(with: SearchLaunchServing.self)
        connection.exportedObject = Launcher()
        connection.resume()
        return true
    }
}

private let delegate = ServiceDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()
