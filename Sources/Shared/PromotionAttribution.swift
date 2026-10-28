import Foundation

/// The capability is kept in RAM and must never become a document URL or diagnostics text.
struct PromotionClaimRequest: CustomStringConvertible {
    let code: String
    let claimID: String
    let receivedAt: Date
    var description: String { "PromotionClaimRequest(redacted)" }
    static func handles(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "markdownpreview" && url.host?.lowercased() == "attribution"
    }
    init?(url: URL, receivedAt: Date = Date()) {
        guard Self.handles(url), url.absoluteString.utf8.count <= 512,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.user == nil, parts.password == nil, parts.port == nil,
              parts.path.isEmpty || parts.path == "/", parts.fragment == nil,
              let items = parts.queryItems, items.count == 1,
              items[0].name == "code", let code = items[0].value,
              code.utf8.count == 64, code.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { return nil }
        self.code = code; self.receivedAt = receivedAt; claimID = UUID().uuidString.lowercased()
    }
}
enum PromotionClaimError: Int, Error, CustomNSError {
    case invalidLink = 1, disabled, identityChanged, expired, conflict, network, service, invalidResponse, cancelled
    static var errorDomain: String { "FluxMarkdownPromotion" }
    var errorCode: Int { rawValue }
    var errorUserInfo: [String: Any] { [:] }
}
struct PromotionClaimAcknowledgement: Decodable {
    let claim_id: String
    let status: String
    let campaign_id: String
    let evidence_grade: String
    func matches(_ request: PromotionClaimRequest) -> Bool {
        claim_id == request.claimID && UUID(uuidString: campaign_id)?.uuidString.lowercased() == campaign_id && evidence_grade == "linked_ticket" &&
        ["pending_activation", "linked", "eligible", "existing", "unattributed", "attributed_provisional", "attributed_mature"].contains(status)
    }
}

/// Public builds always use the fixed endpoint. Tests inject URLProtocol, not a URL from the claim.
final class PromotionClaimClient {
    static let endpoint = URL(string: "https://t.xykong.cc/v1/claims")!
    static let promotionPage = URL(string: "https://t.xykong.cc/promo")!
    private let configuration: URLSessionConfiguration
    private let installation: () -> String?
    private let clientVersion: String
    private var operation: ClaimExchange?
    private var operationID: UUID?
    init(configuration: URLSessionConfiguration = .ephemeral,
         installation: @escaping () -> String?, clientVersion: String) {
        let config = configuration.copy() as! URLSessionConfiguration
        config.timeoutIntervalForRequest = 10; config.timeoutIntervalForResource = 15
        config.httpCookieStorage = nil; config.urlCache = nil; config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.configuration = config; self.installation = installation; self.clientVersion = clientVersion
    }
    func redeem(_ request: PromotionClaimRequest, installationID: String,
                completion: @escaping (Result<PromotionClaimAcknowledgement, PromotionClaimError>) -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.redeem(request, installationID: installationID, completion: completion) }; return
        }
        cancel()
        guard let current = installation() else { completion(.failure(.disabled)); return }
        guard current == installationID, UUID(uuidString: current)?.uuidString.lowercased() == current else { completion(.failure(.identityChanged)); return }
        guard Date().timeIntervalSince(request.receivedAt) >= 0, Date().timeIntervalSince(request.receivedAt) < 600 else { completion(.failure(.expired)); return }
        let body = ["claim_id": request.claimID, "code": request.code, "installation_id": installationID, "client_version": clientVersion]
        guard let encoded = try? JSONEncoder().encode(body), encoded.count <= 4096 else { completion(.failure(.invalidLink)); return }
        var wire = URLRequest(url: Self.endpoint); wire.httpMethod = "POST"; wire.httpBody = encoded
        wire.setValue("application/json", forHTTPHeaderField: "Content-Type")
        wire.setValue("application/json", forHTTPHeaderField: "Accept")
        let id = UUID(); operationID = id
        let exchange = ClaimExchange(configuration: configuration, wire: wire, claim: request, installationID: installationID,
                                     currentInstallation: installation) { [weak self] result in
            if self?.operationID == id { self?.operation = nil; self?.operationID = nil }
            completion(result)
        }
        operation = exchange; exchange.start()
    }
    func cancel() {
        guard Thread.isMainThread else { DispatchQueue.main.async { self.cancel() }; return }
        operation?.cancel(); operation = nil; operationID = nil
    }
}

/// Delegate callbacks are serialized. Completion/session ownership is protected by lock,
/// so a UI cancellation racing a network callback still completes at most once.
private final class ClaimExchange: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let configuration: URLSessionConfiguration
    private let wire: URLRequest
    private let claim: PromotionClaimRequest
    private let installationID: String
    private let currentInstallation: () -> String?
    private let completion: (Result<PromotionClaimAcknowledgement, PromotionClaimError>) -> Void
    private let lock = NSLock()
    private var finished = false
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var bytes = Data()
    private var status = 0
    init(configuration: URLSessionConfiguration, wire: URLRequest, claim: PromotionClaimRequest,
         installationID: String, currentInstallation: @escaping () -> String?,
         completion: @escaping (Result<PromotionClaimAcknowledgement, PromotionClaimError>) -> Void) {
        self.configuration=configuration;self.wire=wire;self.claim=claim;self.installationID=installationID
        self.currentInstallation=currentInstallation;self.completion=completion
    }
    func start() {
        let queue=OperationQueue();queue.maxConcurrentOperationCount=1;queue.name="FluxMarkdown.promotion.response"
        let session=URLSession(configuration:configuration,delegate:self,delegateQueue:queue)
        let task=session.dataTask(with:wire)
        lock.lock();self.session=session;self.task=task;lock.unlock()
        task.resume()
    }
    func cancel() { finish(.failure(.cancelled)) }
    private func finish(_ result: Result<PromotionClaimAcknowledgement, PromotionClaimError>) {
        lock.lock();guard !finished else {lock.unlock();return};finished=true
        let session=self.session;self.session=nil;self.task=nil;lock.unlock()
        session?.invalidateAndCancel()
        DispatchQueue.main.async { self.completion(result) }
    }
    private var isFinished: Bool {lock.lock();defer{lock.unlock()};return finished}
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard !isFinished, let response=response as? HTTPURLResponse else {completionHandler(.cancel);finish(.failure(.invalidResponse));return}
        status=response.statusCode
        if response.expectedContentLength>16384 {completionHandler(.cancel);finish(.failure(.invalidResponse));return}
        completionHandler(.allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !isFinished else{return}
        guard bytes.count+data.count<=16384 else {finish(.failure(.invalidResponse));return}
        bytes.append(data)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil) // Never forward the capability/body to a redirected endpoint.
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !isFinished else{return}
        if error != nil {finish(.failure(.network));return}
        guard currentInstallation()==installationID else {finish(.failure(.identityChanged));return}
        if status==410 {finish(.failure(.expired));return}
        if status==409 {finish(.failure(.conflict));return}
        guard status==200 || status==201 else {finish(.failure(.service));return}
        guard let ack=try? JSONDecoder().decode(PromotionClaimAcknowledgement.self,from:bytes),ack.matches(claim) else {finish(.failure(.invalidResponse));return}
        finish(.success(ack))
    }
}
