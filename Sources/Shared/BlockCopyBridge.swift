import AppKit
import WebKit

/// No document content or clipboard payload is logged or included in diagnostics.
final class BlockCopyBridge {
    struct Request {
        let id: String
        let generation: String
        let text: String
    }
    private var scope = ""
    private var lastRequestID: UInt64 = 0

    static func request(_ body: Any, generation: String, enabled: Bool) -> Request? {
        guard enabled, let fields = body as? [String: Any],
              Set(fields.keys) == Set(["id", "generation", "text"]),
              let id = fields["id"] as? String, !id.isEmpty, id.utf8.count <= 32,
              id.utf8.allSatisfy({ (48...57).contains($0) }), UInt64(id) != nil,
              let document = fields["generation"] as? String, !document.isEmpty, document == generation,
              let text = fields["text"] as? String, text.utf8.count <= 4 * 1024 * 1024 else { return nil }
        return Request(id: id, generation: document, text: text)
    }

    static func write(_ text: String, to pasteboard: NSPasteboard = .general) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }

    func acceptSequence(_ request: Request) -> Bool {
        if scope != request.generation { scope = request.generation; lastRequestID = 0 }
        guard let id = UInt64(request.id), id > lastRequestID else { return false }
        lastRequestID = id
        return true
    }

    func handle(_ message: WKScriptMessage, generation: String, enabled: Bool) {
        guard RendererBridgePolicy.accepts(message),
              let request = Self.request(message.body, generation: generation, enabled: enabled),
              let webView = message.webView else { return }
        guard acceptSequence(request) else { return }
        let success = Self.write(request.text)
        webView.callAsyncJavaScript(
            "window.blockCopyResult && window.blockCopyResult(id, generation, success);",
            arguments: ["id": request.id, "generation": request.generation, "success": success],
            in: nil, in: .page, completionHandler: nil)
    }
}
