import AppKit
import WebKit
import Foundation

struct DiagramExportRequest {
    let id:String
    let generation:String
    let action:String
    let svg:String
    static func decode(_ body:Any,generation:String)->Self? {
        guard let value=body as? [String:Any],Set(value.keys)==Set(["id","generation","action","svg"]),
              let id=value["id"] as? String,!id.isEmpty,id.utf8.count<=32,id.utf8.allSatisfy({(48...57).contains($0)}),UInt64(id) != nil,
              value["generation"] as? String==generation,
              let action=value["action"] as? String,["copy","png","svg"].contains(action),
              let svg=value["svg"] as? String,svg.utf8.count<=8*1024*1024 else{return nil}
        return Self(id:id,generation:generation,action:action,svg:svg)
    }
}

private final class SVGExportValidator:NSObject,XMLParserDelegate {
    var valid=true
    var width:Double=0,height:Double=0
    var nodes=0
    var styleText=""
    var inStyle=false
    private func safeCSS(_ text:String)->Bool {
        let css=text.lowercased()
        guard !css.contains("@import"),!css.contains("\\") else{return false}
        guard let regex=try? NSRegularExpression(pattern:#"url\(([^)]*)\)"#) else{return false}
        for match in regex.matches(in:css,range:NSRange(css.startIndex...,in:css)) {
            guard let range=Range(match.range(at:1),in:css) else{return false}
            let target=css[range].trimmingCharacters(in:CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn:"\"'")))
            if !target.hasPrefix("#") && !target.hasPrefix("data:image/"){return false}
        }
        return true
    }
    func parser(_ parser:XMLParser,didStartElement name:String,namespaceURI:String?,qualifiedName:String?,attributes:[String:String]) {
        nodes+=1
        if name.lowercased()=="style"{inStyle=true;styleText=""}
        if nodes==1 {
            valid=name=="svg" && namespaceURI=="http://www.w3.org/2000/svg"
            width=Double(attributes["width"] ?? "") ?? 0;height=Double(attributes["height"] ?? "") ?? 0
        }
        if nodes>20000 || (["script","iframe","object","embed","audio","video","set","form","input","meta","link","base"].contains(name.lowercased()) || name.lowercased().hasPrefix("animate")){valid=false}
        for (key,value) in attributes {
            let key=key.lowercased().split(separator:":").last.map(String.init) ?? "", value=value.lowercased()
            if key.hasPrefix("on") || (key.hasSuffix("href") && !value.hasPrefix("#") && !value.hasPrefix("data:image/") && !(name=="a" && (value.hasPrefix("https://") || value.hasPrefix("http://")))) || value.contains("javascript:"){valid=false}
            if (key=="style" || value.contains("url(")) && !safeCSS(value){valid=false}
            if ["src","srcset","poster","data"].contains(key) && !value.hasPrefix("data:image/"){valid=false}
        }
        if !valid{parser.abortParsing()}
    }
    func parser(_ parser:XMLParser,foundCharacters string:String){if inStyle{styleText+=string}}
    func parser(_ parser:XMLParser,foundCDATA block:Data){if inStyle{styleText+=String(decoding:block,as:UTF8.self)}}
    func parser(_ parser:XMLParser,didEndElement name:String,namespaceURI:String?,qualifiedName:String?) {
        if name.lowercased()=="style" {
            inStyle=false
            if !safeCSS(styleText){valid=false}
            if !valid{parser.abortParsing()}
        }
    }
}

final class DiagramRasterizer:NSObject,WKNavigationDelegate {
    private var webView:WKWebView?
    private var completion:((Result<Data,Error>)->Void)?
    static func dimensions(_ svg:String)->CGSize? {
        guard !svg.isEmpty,svg.utf8.count<=8*1024*1024,!svg.localizedCaseInsensitiveContains("<!DOCTYPE"),!svg.localizedCaseInsensitiveContains("<!ENTITY") else{return nil}
        let validator=SVGExportValidator(),parser=XMLParser(data:Data(svg.utf8));parser.delegate=validator;parser.shouldResolveExternalEntities=false;parser.shouldProcessNamespaces=true
        guard parser.parse(),validator.valid,validator.width.isFinite,validator.height.isFinite,
              validator.width>0,validator.height>0,validator.width<=1_000_000,validator.height<=1_000_000 else{return nil}
        let scale=min(2,2048/max(validator.width,validator.height))
        return CGSize(width:max(1,(validator.width*scale).rounded()),height:max(1,(validator.height*scale).rounded()))
    }
    func render(_ svg:String,completion:@escaping(Result<Data,Error>)->Void) {
        guard let size=Self.dimensions(svg) else{completion(.failure(NSError(domain:"DiagramExport",code:1)));return}
        self.completion=completion
        let config=WKWebViewConfiguration();config.defaultWebpagePreferences.allowsContentJavaScript=false
        let view=WKWebView(frame:CGRect(origin:.zero,size:size),configuration:config);webView=view;view.navigationDelegate=self
        let html="<html><head><meta http-equiv='Content-Security-Policy' content=\"default-src 'none'; style-src 'unsafe-inline'; img-src data:; font-src data:\"></head><body style='margin:0;overflow:hidden'><div style='width:100vw;height:100vh'>\(svg)</div><style>svg{width:100vw!important;height:100vh!important}</style></body></html>"
        view.loadHTMLString(html,baseURL:nil)
        DispatchQueue.main.asyncAfter(deadline:.now()+15){[weak self] in self?.finish(.failure(NSError(domain:"DiagramExport",code:2)))}
    }
    func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!) {
        let configuration=WKSnapshotConfiguration();configuration.afterScreenUpdates=true
        webView.takeSnapshot(with:configuration){[weak self] image,error in
            guard let image,let tiff=image.tiffRepresentation,let bitmap=NSBitmapImageRep(data:tiff),let data=bitmap.representation(using:.png,properties:[:]) else{self?.finish(.failure(error ?? NSError(domain:"DiagramExport",code:3)));return}
            self?.finish(.success(data))
        }
    }
    func webView(_ webView:WKWebView,didFail navigation:WKNavigation!,withError error:Error){finish(.failure(error))}
    func webView(_ webView:WKWebView,didFailProvisionalNavigation navigation:WKNavigation!,withError error:Error){finish(.failure(error))}
    private func finish(_ result:Result<Data,Error>){guard let completion else{return};self.completion=nil;webView=nil;completion(result)}
}

final class DiagramExportService {
    private var rasterizers:[String:DiagramRasterizer]=[:]
    static func write(_ data:Data,to url:URL)throws {try data.write(to:url,options:.atomic);guard try Data(contentsOf:url)==data else{throw NSError(domain:"DiagramExport",code:4)}}
    func perform(_ request:DiagramExportRequest,destination:URL?=nil,pasteboard:NSPasteboard = .general,completion:@escaping(Result<String,Error>)->Void) {
        guard DiagramRasterizer.dimensions(request.svg) != nil else{completion(.failure(NSError(domain:"DiagramExport",code:1)));return}
        let finish:(Data)->Void={data in
            do {
                if request.action=="copy" {pasteboard.clearContents();guard pasteboard.setData(data,forType:.png),pasteboard.data(forType:.png)==data else{throw NSError(domain:"DiagramExport",code:5)};completion(.success("copied"))}
                else if let destination {try Self.write(data,to:destination);completion(.success("saved"))}
                else {completion(.success("cancelled"))}
            } catch {completion(.failure(error))}
        }
        if request.action=="svg" {finish(Data(request.svg.utf8));return}
        let rasterizer=DiagramRasterizer();let key=request.generation+":"+request.id;rasterizers[key]=rasterizer
        rasterizer.render(request.svg){result in
            self.rasterizers.removeValue(forKey:key)
            switch result{case .success(let data):finish(data);case .failure(let error):completion(.failure(error))}
        }
    }
}
