import XCTest
import Foundation

private final class ClaimTestProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.handler else { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)); return }
        let (status, data) = handler(request)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
final class PromotionAttributionTests: XCTestCase {
    private let code = String(repeating: "a", count: 64)
    private func request(at: Date = Date()) throws -> PromotionClaimRequest {
        try XCTUnwrap(PromotionClaimRequest(url: URL(string: "markdownpreview://attribution?code=\(code)")!, receivedAt: at))
    }
    private func client(_ installation: @escaping () -> String?) -> PromotionClaimClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ClaimTestProtocol.self]
        return PromotionClaimClient(configuration: config, installation: installation, clientVersion: "1.0.0")
    }
    func testStrictURLGrammarRejectsDestinationsAndPrivateContent() throws {
        XCTAssertNotNil(try request())
        for value in [
            "https://attribution?code=\(code)", "markdownpreview://open?code=\(code)",
            "markdownpreview://attribution/file?code=\(code)", "markdownpreview://user@attribution?code=\(code)",
            "markdownpreview://attribution:80?code=\(code)", "markdownpreview://attribution?code=\(code)&code=\(code)",
            "markdownpreview://attribution?code=\(code)&callback=https://evil.test",
            "markdownpreview://attribution?code=\(code)#fragment", "markdownpreview://attribution?code=short"
        ] { XCTAssertNil(PromotionClaimRequest(url: URL(string:value)!)) }
        XCTAssertFalse(String(describing: try request()).contains(code))
    }
    func testDisabledIdentityChangeAndExpiryDoNotMakeRequests() throws {
        var requests = 0
        ClaimTestProtocol.handler = { _ in requests += 1; return (500, Data()) }
        defer { ClaimTestProtocol.handler = nil }
        let id = UUID().uuidString.lowercased()
        let disabled = client { nil }
        let changed = client { UUID().uuidString.lowercased() }
        let expired = client { id }
        let done = expectation(description: "all preflight failures"); done.expectedFulfillmentCount = 3
        disabled.redeem(try request(), installationID: id) { result in XCTAssertEqual(result.failure, .disabled); done.fulfill() }
        changed.redeem(try request(), installationID: id) { result in XCTAssertEqual(result.failure, .identityChanged); done.fulfill() }
        expired.redeem(try request(at: Date().addingTimeInterval(-601)), installationID: id) { result in XCTAssertEqual(result.failure, .expired); done.fulfill() }
        wait(for:[done], timeout:3); XCTAssertEqual(requests,0)
    }
    func testFixedEndpointMinimalPayloadAndStableRetryIdentity() throws {
        let id = UUID().uuidString.lowercased(); let claim = try request(); let network = client { id }
        var attempts = 0
        ClaimTestProtocol.handler = { request in
            attempts += 1
            XCTAssertEqual(request.url?.absoluteString, "https://t.xykong.cc/v1/claims")
            XCTAssertEqual(request.httpMethod, "POST")
            var data = request.httpBody ?? Data()
            if data.isEmpty, let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }; var bytes = [UInt8](repeating:0,count:4096)
                while stream.hasBytesAvailable { let n=stream.read(&bytes,maxLength:bytes.count); if n<=0 {break};data.append(contentsOf:bytes.prefix(n)) }
            }
            let body = try! JSONSerialization.jsonObject(with:data) as! [String:String]
            XCTAssertEqual(Set(body.keys),Set(["claim_id","code","installation_id","client_version"]))
            XCTAssertEqual(body["claim_id"],claim.claimID);XCTAssertEqual(body["installation_id"],id)
            if attempts==1 {return (503,Data())}
            let response:[String:Any] = ["claim_id":claim.claimID,"status":"pending_activation","campaign_id":UUID().uuidString.lowercased(),"evidence_grade":"linked_ticket"]
            return (201,try! JSONSerialization.data(withJSONObject:response))
        }
        defer { ClaimTestProtocol.handler = nil }
        let first=expectation(description:"transient failure")
        network.redeem(claim,installationID:id){result in XCTAssertEqual(result.failure,.service);first.fulfill()}
        wait(for:[first],timeout:3)
        let retry=expectation(description:"explicit retry")
        network.redeem(claim,installationID:id){result in if case .success(let ack)=result {XCTAssertEqual(ack.status,"pending_activation")} else {XCTFail("expected association ACK")};retry.fulfill()}
        wait(for:[retry],timeout:3);XCTAssertEqual(attempts,2)
    }
    func testOversizedAndMismatchedAcknowledgementsAreRejected() throws {
        let id=UUID().uuidString.lowercased();let network=client{id};let claim=try request()
        for data in [Data(repeating:120,count:20000),try JSONSerialization.data(withJSONObject:["claim_id":UUID().uuidString.lowercased(),"status":"pending_activation","campaign_id":UUID().uuidString.lowercased(),"evidence_grade":"linked_ticket"])] {
            ClaimTestProtocol.handler={_ in(200,data)}
            let done=expectation(description:"invalid response")
            network.redeem(claim,installationID:id){result in XCTAssertEqual(result.failure,.invalidResponse);done.fulfill()}
            wait(for:[done],timeout:3)
        }
        ClaimTestProtocol.handler=nil
    }
}
private extension Result where Failure == PromotionClaimError {
    var failure: PromotionClaimError? { if case .failure(let error)=self {return error};return nil }
}

extension PromotionAttributionTests {
    func testIdentityChangeWhileRequestIsInFlightDoesNotReportLinked() throws {
        let id=UUID().uuidString.lowercased();var enabled=true;let lock=NSLock()
        let network=client { lock.lock();defer{lock.unlock()};return enabled ? id : nil }
        let claim=try request()
        ClaimTestProtocol.handler={_ in
            lock.lock();enabled=false;lock.unlock()
            return (200,try! JSONSerialization.data(withJSONObject:["claim_id":claim.claimID,"status":"pending_activation","campaign_id":UUID().uuidString.lowercased(),"evidence_grade":"linked_ticket"]))
        }
        defer {ClaimTestProtocol.handler=nil}
        let done=expectation(description:"identity check at completion")
        network.redeem(claim,installationID:id){result in XCTAssertEqual(result.failure,.identityChanged);done.fulfill()}
        wait(for:[done],timeout:3)
    }
    func testCancelCompletesOnceDespiteLateNetworkReply() throws {
        let id=UUID().uuidString.lowercased();let network=client{id};let claim=try request()
        let started=expectation(description:"request started")
        ClaimTestProtocol.handler={_ in
            started.fulfill();Thread.sleep(forTimeInterval:0.2)
            return (200,try! JSONSerialization.data(withJSONObject:["claim_id":claim.claimID,"status":"pending_activation","campaign_id":UUID().uuidString.lowercased(),"evidence_grade":"linked_ticket"]))
        }
        defer {ClaimTestProtocol.handler=nil}
        var completed=0;let cancelled=expectation(description:"cancelled once")
        network.redeem(claim,installationID:id){result in completed+=1;XCTAssertEqual(result.failure,.cancelled);cancelled.fulfill()}
        wait(for:[started],timeout:3);network.cancel();wait(for:[cancelled],timeout:3)
        let drained=expectation(description:"late reply drained")
        DispatchQueue.main.asyncAfter(deadline:.now()+0.3){drained.fulfill()}
        wait(for:[drained],timeout:3);XCTAssertEqual(completed,1)
    }
}
