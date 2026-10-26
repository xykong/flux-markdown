import Foundation

enum SearchLaunchClient {
    static func flushUsage(completion: @escaping (Bool) -> Void) {
        perform({ $0.flushUsage(reply: $1) }, timeout: 20, completion: completion)
    }
    static func openForReading(_ fileURL: URL, completion: @escaping (Bool) -> Void) {
        guard let searchURL = DocumentOpenRequest.searchURL(for: fileURL), SearchLaunchPolicy.request(searchURL.absoluteString) != nil,
              var components = URLComponents(url: searchURL, resolvingAgainstBaseURL: false) else { completion(false); return }
        components.queryItems?.removeAll { $0.name == "find" }
        guard let url = components.url else { completion(false); return }
        perform { $0.openDocument(url.absoluteString, reply: $1) } completion: { completion($0) }
    }
    static func reportError(_ data: Data, completion: @escaping (Bool) -> Void) {
        guard IncidentFeedbackRequest.decode(data) != nil else { completion(false); return }
        perform { $0.reportError(data, reply: $1) } completion: { completion($0) }
    }
    static func open(_ url: URL, completion: @escaping (Bool) -> Void) {
        guard SearchLaunchPolicy.request(url.absoluteString) != nil else { completion(false); return }
        perform { $0.openDocumentSearch(url.absoluteString, reply: $1) } completion: { completion($0) }
    }

    static func openGitHubRepository(completion: @escaping (Bool) -> Void) {
        perform { $0.openGitHubRepository(reply: $1) } completion: { completion($0) }
    }

    private static func perform(_ action: (SearchLaunchServing, @escaping (Bool) -> Void) -> Void,
                                timeout: TimeInterval = 8, completion: @escaping (Bool) -> Void) {
        let connection = NSXPCConnection(serviceName: SearchLaunchPolicy.serviceName)
        connection.remoteObjectInterface = NSXPCInterface(with: SearchLaunchServing.self)
        let lock = NSLock()
        var completed = false
        func finish(_ success: Bool) {
            lock.lock()
            guard !completed else { lock.unlock(); return }
            completed = true
            lock.unlock()
            connection.interruptionHandler = nil
            connection.invalidationHandler = nil
            connection.invalidate()
            DispatchQueue.main.async { completion(success) }
        }
        connection.interruptionHandler = { finish(false) }
        connection.invalidationHandler = { finish(false) }
        connection.resume()
        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in finish(false) }) as? SearchLaunchServing else {
            finish(false); return
        }
        action(proxy, finish)
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { finish(false) }
    }
}
