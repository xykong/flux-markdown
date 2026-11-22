import AppKit
import WebKit
import CryptoKit
import Combine

struct ReadingSnapshot: Codable, Equatable {
    var id: String
    var hash: String
    var index: Int
    var top: Double
    var scrollY: Double
    var zoom: Double
    static let initial = ReadingSnapshot(id:"", hash:"", index:0, top:0, scrollY:0, zoom:1)
    var valid: Bool { id.utf8.count <= 1024 && hash.utf8.count <= 16 && (0...1_000_000).contains(index) && top.isFinite && abs(top) <= 10_000_000 && scrollY.isFinite && (0...1_000_000_000).contains(scrollY) && zoom.isFinite && (0.5...3).contains(zoom) }
    init?(body: Any) {
        guard let value=body as? [String:Any], Set(value.keys)==Set(["id","hash","index","top","scrollY","zoom"]),
              let data=try? JSONSerialization.data(withJSONObject:value),
              let decoded=try? JSONDecoder().decode(Self.self,from:data), decoded.valid else {return nil}
        self=decoded
    }
    init(id:String,hash:String,index:Int,top:Double,scrollY:Double,zoom:Double) {self.id=id;self.hash=hash;self.index=index;self.top=top;self.scrollY=scrollY;self.zoom=zoom}
    var object: [String:Any] { ["id":id,"hash":hash,"index":index,"top":top,"scrollY":scrollY,"zoom":zoom] }
}

final class ReadingJourneyStore:ObservableObject {
    struct Entry: Codable { let path: String; var state: ReadingSnapshot; var url: URL { URL(fileURLWithPath:path) } }
    static let shared=ReadingJourneyStore()
    static let changed=Notification.Name("FluxMarkdown.readingJourneyChanged")
    static let restore=Notification.Name("FluxMarkdown.restoreReadingSnapshot")
    private func changed() {objectWillChange.send();NotificationCenter.default.post(name:Self.changed,object:nil)}
    private let defaults: UserDefaults
    private let key="readingSnapshots.v1"
    private var records: [Entry]=[]
    private(set) var history: [Entry]=[]
    private(set) var cursor = -1
    private var pending: [String:ReadingSnapshot]=[:]
    init(defaults:UserDefaults = .standard) {
        self.defaults=defaults
        if let data=defaults.data(forKey:key), data.count<=1024*1024,
           let values=try? JSONDecoder().decode([Entry].self,from:data) {
            records=Array(values.filter{$0.path.hasPrefix("/") && !$0.path.contains("\0") && $0.state.valid}.prefix(100))
        }
    }
    static func path(_ url:URL)->String {url.standardizedFileURL.resolvingSymlinksInPath().path}
    static func documentID(_ url:URL)->String {SHA256.hash(data:Data(path(url).utf8)).map{String(format:"%02x",$0)}.joined()}
    var canBack:Bool {cursor>0}
    var canForward:Bool {cursor>=0 && cursor<history.count-1}
    func state(for url:URL)->ReadingSnapshot? {records.first{$0.path==Self.path(url)}?.state}
    func save(_ state:ReadingSnapshot,for url:URL) {
        guard url.isFileURL,state.valid else{return}
        let path=Self.path(url)
        records.removeAll{$0.path==path};records.insert(Entry(path:path,state:state),at:0)
        records=Array(records.prefix(100))
        if let data=try? JSONEncoder().encode(records){defaults.set(data,forKey:key)}
        if history.indices.contains(cursor),history[cursor].path==path{history[cursor].state=state}
    }
    private func start(_ entry:Entry) {
        if history.indices.contains(cursor),history[cursor].path==entry.path {history[cursor]=entry}
        else {history=Array(history.prefix(cursor+1));history.append(entry);cursor=history.count-1}
    }
    private func append(_ entry:Entry) {
        history=Array(history.prefix(cursor+1));history.append(entry)
        if history.count>100{history.removeFirst()};cursor=history.count-1
        changed()
    }
    func jump(in url:URL,from before:ReadingSnapshot,to after:ReadingSnapshot) {
        start(Entry(path:Self.path(url),state:before));append(Entry(path:Self.path(url),state:after));save(after,for:url)
    }
    func followedLink(from origin:URL,state:ReadingSnapshot,to target:URL) {
        start(Entry(path:Self.path(origin),state:state));append(Entry(path:Self.path(target),state:self.state(for:target) ?? .initial))
    }
    func step(_ direction:Int,from url:URL,state:ReadingSnapshot)->Entry? {
        save(state,for:url)
        let next=cursor+(direction<0 ? -1:1)
        guard history.indices.contains(next) else{return nil}
        cursor=next;let entry=history[next];pending[entry.path]=entry.state
        save(entry.state,for:entry.url)
        changed()
        return entry
    }
    func consumeRestore(for url:URL)->ReadingSnapshot? {pending.removeValue(forKey:Self.path(url))}
    func navigate(_ direction:Int,from url:URL,state:ReadingSnapshot,controller:NSDocumentController = .shared) {
        let oldCursor=cursor
        guard let entry=step(direction,from:url,state:state) else{return}
        controller.openDocument(withContentsOf:entry.url,display:true){_,_,error in
            if let error {
                self.cursor=oldCursor;self.pending.removeValue(forKey:entry.path)
                self.changed()
                ErrorFeedback.present(ErrorFeedback.capture(.fileRead,error:error),recoveryTitle:"Choose Another File",recovery:{controller.openDocument(nil)})
            } else {NotificationCenter.default.post(name:Self.restore,object:entry.url)}
        }
    }
}

final class ReadingJourneyBridge {
    static func options(for url:URL)->[String:Any] {
        var options:[String:Any]=["documentId":ReadingJourneyStore.documentID(url)]
        if let state=ReadingJourneyStore.shared.state(for:url){options["readingState"]=state.object}
        return options
    }
    static func update(_ webView:WKWebView) {
        let store=ReadingJourneyStore.shared
        webView.callAsyncJavaScript("window.updateReadingNavigation?.(back,forward)",arguments:["back":store.canBack,"forward":store.canForward],in:nil,in:.page,completionHandler:nil)
    }
    static func restore(_ webView:WKWebView,url:URL,store:ReadingJourneyStore = .shared) {
        guard let state=store.consumeRestore(for:url) else{return}
        webView.callAsyncJavaScript("window.closeDiagramFocus?.();window.restoreReadingState?.(state)",arguments:["state":state.object],in:nil,in:.page){_ in}
        (webView as? NativeMagnifyingWebView)?.adoptReadingZoom(CGFloat(state.zoom))
    }
    static func handle(_ message:WKScriptMessage,url:URL?,generation:String,allowNavigation:Bool) {
        guard RendererBridgePolicy.accepts(message),let url,
              let body=message.body as? [String:Any],body["generation"] as? String==generation,
              body["documentId"] as? String==ReadingJourneyStore.documentID(url),
              Set(body.keys).isSubset(of:["action","generation","documentId","state","before","after","direction"]),
              let action=body["action"] as? String else{return}
        let store=ReadingJourneyStore.shared
        switch action {
        case "save":if let state=body["state"].flatMap(ReadingSnapshot.init(body:)){store.save(state,for:url);(message.webView as? NativeMagnifyingWebView)?.adoptReadingZoom(CGFloat(state.zoom))}
        case "jump":if allowNavigation,let before=body["before"].flatMap(ReadingSnapshot.init(body:)),let after=body["after"].flatMap(ReadingSnapshot.init(body:)){store.jump(in:url,from:before,to:after)}
        case "navigate":if allowNavigation,let direction=body["direction"] as? Int,[-1,1].contains(direction),let state=body["state"].flatMap(ReadingSnapshot.init(body:)){store.navigate(direction,from:url,state:state)}
        case "availability":break
        default:return
        }
        if let webView=message.webView{update(webView)}
    }
}
