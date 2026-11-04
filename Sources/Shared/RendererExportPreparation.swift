import Foundation

enum RendererExportFailure: Error {
    case mathematics
    case other(Error?)
}

enum RendererExportPreparation: Equatable {
    case ready(html: String?)
    case mathematics

    static func decode(_ value: Any) -> Self? {
        guard let body=value as? [String:Any], let status=body["status"] as? String else { return nil }
        if status == "mathematics" {
            return Set(body.keys) == ["status"] ? .mathematics : nil
        }
        guard status == "ready", Set(body.keys).isSubset(of:["status","html"]) else { return nil }
        if let html=body["html"] {
            guard let text=html as? String else { return nil }
            return .ready(html:text)
        }
        return .ready(html:nil)
    }

    static let htmlScript = """
    const preparation=await window.prepareExport();
    return preparation.status==='ready' ? {status:'ready',html:window.exportHTML()} : preparation;
    """
    static let pdfScript = """
    const preparation=await window.prepareExport();
    if(preparation.status==='ready')document.documentElement.style.setProperty('--print-font-size',String(fontSize)+'px');
    return preparation;
    """
}
