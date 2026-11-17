import XCTest
import WebKit

@MainActor final class ReadingWorkflowTests:XCTestCase {
    let sample=ReadingSnapshot(id:"section",hash:"a1b2",index:4,top:120,scrollY:900,zoom:1.5)
    func testSnapshotsValidateAndPersistWithoutDocumentText() throws {
        let name="ReadingWorkflow."+UUID().uuidString,defaults=try XCTUnwrap(UserDefaults(suiteName:name))
        defer{defaults.removePersistentDomain(forName:name)}
        let store=ReadingJourneyStore(defaults:defaults),url=URL(fileURLWithPath:"/tmp/reader-a.md")
        store.save(sample,for:url)
        XCTAssertEqual(ReadingJourneyStore(defaults:defaults).state(for:url),sample)
        XCTAssertNotEqual(ReadingJourneyStore.documentID(url),url.path)
        var invalid=sample.object;invalid["zoom"]=true
        XCTAssertNil(ReadingSnapshot(body:invalid))
        invalid=sample.object;invalid["index"] = -1;XCTAssertNil(ReadingSnapshot(body:invalid))
        for i in 0..<105{store.save(sample,for:URL(fileURLWithPath:"/tmp/reader-\(i).md"))}
        XCTAssertNil(store.state(for:url))
    }
    func testHistoryBackForwardAndNewBranch() throws {
        let name="ReadingWorkflow."+UUID().uuidString,defaults=try XCTUnwrap(UserDefaults(suiteName:name))
        defer{defaults.removePersistentDomain(forName:name)}
        let store=ReadingJourneyStore(defaults:defaults),a=URL(fileURLWithPath:"/tmp/a.md"),b=URL(fileURLWithPath:"/tmp/b.md")
        store.followedLink(from:a,state:sample,to:b)
        XCTAssertTrue(store.canBack)
        let back=try XCTUnwrap(store.step(-1,from:b,state:.initial))
        XCTAssertEqual(back.path,a.path);XCTAssertEqual(back.state,sample);XCTAssertTrue(store.canForward)
        let forward=try XCTUnwrap(store.step(1,from:a,state:sample));XCTAssertEqual(forward.path,b.path)
        _=store.step(-1,from:b,state:.initial)
        store.jump(in:a,from:sample,to:.initial)
        XCTAssertFalse(store.canForward)
    }
    func testDiagramRequestsRejectStaleAndUnsafePayloads() {
        let svg="<svg xmlns='http://www.w3.org/2000/svg' width='100' height='60'><rect width='100' height='60' fill='red'/></svg>"
        XCTAssertNotNil(DiagramRasterizer.dimensions(svg))
        XCTAssertNil(DiagramRasterizer.dimensions(svg.replacingOccurrences(of:"<rect",with:"<script/><rect")))
        XCTAssertNil(DiagramRasterizer.dimensions("<svg xmlns='http://www.w3.org/2000/svg' width='100' height='60'><style>rect{fill:url(https://example.com/a)}</style></svg>"))
        XCTAssertNil(DiagramRasterizer.dimensions("<!DOCTYPE svg><svg width='1' height='1'/>"))
        XCTAssertNil(DiagramRasterizer.dimensions("<svg xmlns='http://www.w3.org/2000/svg' width='100' height='60'><rect fill='url(https://example.com/a)'/></svg>"))
        XCTAssertNil(DiagramRasterizer.dimensions("<svg xmlns='http://www.w3.org/2000/svg' width='100' height='60'><style><![CDATA[@import url(https://example.com/a);]]></style></svg>"))
        XCTAssertNil(DiagramExportRequest.decode(["id":"1","generation":"old","action":"copy","svg":svg],generation:"current"))
        XCTAssertNotNil(DiagramExportRequest.decode(["id":"1","generation":"current","action":"copy","svg":svg],generation:"current"))
    }
    func testSVGFileAndRealPNGPasteboardReadback() throws {
        let svg="<svg xmlns='http://www.w3.org/2000/svg' width='100' height='60' viewBox='0 0 100 60'><rect width='100' height='60' fill='red'/><text x='10' y='30'>Diagram</text></svg>"
        let bridge=DiagramExportService(),url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".svg")
        defer{try? FileManager.default.removeItem(at:url)}
        let saved=expectation(description:"saved SVG")
        bridge.perform(DiagramExportRequest(id:"1",generation:"g",action:"svg",svg:svg),destination:url){result in
            XCTAssertEqual(try? result.get(),"saved");saved.fulfill()
        }
        wait(for:[saved],timeout:3)
        XCTAssertEqual(try String(contentsOf:url),svg)
        let pasteboard=NSPasteboard.withUniqueName(),copied=expectation(description:"actual WebKit PNG")
        defer{pasteboard.releaseGlobally()}
        bridge.perform(DiagramExportRequest(id:"2",generation:"g",action:"copy",svg:svg),pasteboard:pasteboard){result in
            XCTAssertEqual(try? result.get(),"copied")
            let data=pasteboard.data(forType:.png)
            XCTAssertEqual(data?.prefix(8),Data([137,80,78,71,13,10,26,10]))
            if let data,let bitmap=NSBitmapImageRep(data:data){XCTAssertGreaterThan(bitmap.pixelsWide,0);XCTAssertLessThanOrEqual(bitmap.pixelsWide,4096);if let color=bitmap.colorAt(x:5,y:5)?.usingColorSpace(.deviceRGB){XCTAssertGreaterThan(color.redComponent,0.8);XCTAssertLessThan(color.greenComponent,0.2)}else{XCTFail("PNG color missing")}}else{XCTFail("PNG did not decode")}
            copied.fulfill()
        }
        wait(for:[copied],timeout:20)
    }
}

@MainActor private final class JourneyProbeDocument:NSDocument,WKScriptMessageHandler {
    static var store:ReadingJourneyStore?
    static var loaded:((JourneyProbeDocument,[String:Any])->Void)?
    var webView:WKWebView?
    private var markdown=""
    override class var readableTypes:[String]{["public.plain-text"]}
    override func read(from url:URL,ofType typeName:String)throws {
        let text=try String(contentsOf:url,encoding:.utf8)
        DispatchQueue.main.async {self.markdown=text;self.startRenderer()}
    }
    override func makeWindowControllers() {}
    override func showWindows() {}
    private func startRenderer() {
        let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("web-renderer/dist")
        let config=WKWebViewConfiguration();config.userContentController.add(self,name:"logger")
        config.setURLSchemeHandler(RendererBundleSchemeHandler(rootDirectory:root),forURLScheme:RendererBundleSchemeHandler.scheme)
        let view=WKWebView(frame:NSRect(x:0,y:0,width:1000,height:700),configuration:config);webView=view
        view.load(URLRequest(url:RendererBundleSchemeHandler.rendererURL()))
    }
    func userContentController(_ userContentController:WKUserContentController,didReceive message:WKScriptMessage) {
        guard message.body as? String=="rendererReady",let webView,let fileURL,let store=Self.store else{return}
        webView.callAsyncJavaScript("await window.renderMarkdown(text,{context:'app'});",arguments:["text":markdown],in:nil,in:.page){result in
            if case .failure = result {Self.loaded?(self,["failed":true]);return}
            ReadingJourneyBridge.restore(webView,url:fileURL,store:store)
            webView.callAsyncJavaScript("return {top:document.getElementById('journey-destination')?.getBoundingClientRect().top,zoom:document.getElementById('markdown-preview').style.getPropertyValue('zoom')};",arguments:[:],in:nil,in:.page){result in
                if case .success(let value)=result,let value=value as? [String:Any]{Self.loaded?(self,value)}else{Self.loaded?(self,["failed":true])}
            }
        }
    }
}

@MainActor private final class JourneyProbeController:NSDocumentController {
    override func documentClass(forType typeName:String)->AnyClass? {JourneyProbeDocument.self}
    override func typeForContents(of url:URL)throws->String {"public.plain-text"}
}

extension ReadingWorkflowTests {
    func testCrossFileHistoryOpensRealDocumentsAndRestoresWebKitAnchor() throws {
        let name="ReadingJourneyE2E."+UUID().uuidString,defaults=try XCTUnwrap(UserDefaults(suiteName:name))
        let store=ReadingJourneyStore(defaults:defaults),controller=JourneyProbeController()
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        defer{defaults.removePersistentDomain(forName:name);try? FileManager.default.removeItem(at:directory);JourneyProbeDocument.store=nil;JourneyProbeDocument.loaded=nil;controller.documents.filter{$0 is JourneyProbeDocument}.forEach{$0.close()}}
        let a=directory.appendingPathComponent("origin.txt"),b=directory.appendingPathComponent("linked.txt")
        try ((0..<40).map{"Paragraph \($0)"}.joined(separator:"\n\n")+"\n\n## Journey Destination\n\n"+String(repeating:"After target.\n\n",count:40)).write(to:a,atomically:true,encoding:.utf8)
        try "# Linked\n\nLinked document.".write(to:b,atomically:true,encoding:.utf8)
        JourneyProbeDocument.store=store
        let state=ReadingSnapshot(id:"journey-destination",hash:"",index:40,top:120,scrollY:900,zoom:1.5)
        store.followedLink(from:a,state:state,to:b)
        let complete=expectation(description:"real document back and forward")
        var phase=0
        JourneyProbeDocument.loaded={document,value in
            if phase==0 {
                XCTAssertEqual(document.fileURL?.path,a.path)
                XCTAssertEqual(value["zoom"] as? String,"1.5")
                XCTAssertEqual((value["top"] as? Double) ?? -100,120,accuracy:3)
                phase=1;store.navigate(1,from:a,state:state,controller:controller)
            } else {
                XCTAssertEqual(document.fileURL?.path,b.path)
                XCTAssertEqual(value["zoom"] as? String,"1")
                complete.fulfill()
            }
        }
        store.navigate(-1,from:b,state:.initial,controller:controller)
        wait(for:[complete],timeout:30)
    }
}
