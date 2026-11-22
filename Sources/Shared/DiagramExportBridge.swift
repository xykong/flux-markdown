import AppKit
import WebKit

final class DiagramExportBridge {
    private let service=DiagramExportService()
    private var lastRequest:UInt64=0
    private var scope=""
    func handle(_ message:WKScriptMessage,generation:String,fileURL:URL?,quickLook:Bool,isCurrent:@escaping()->Bool,reload:@escaping()->Void) {
        guard RendererBridgePolicy.accepts(message),let request=DiagramExportRequest.decode(message.body,generation:generation),let webView=message.webView else{return}
        if scope != generation{scope=generation;lastRequest=0}
        guard let sequence=UInt64(request.id),sequence>lastRequest else{return};lastRequest=sequence
        weak var target=webView
        weak var notice:IncidentNotice?
        func reply(_ status:String){target?.callAsyncJavaScript("window.diagramActionResult?.(id,generation,status)",arguments:["id":request.id,"generation":generation,"status":status],in:nil,in:.page,completionHandler:nil)}
        if quickLook && request.action != "copy" {
            guard let fileURL else{reply("failed");return}
            func openApp(){SearchLaunchClient.openForReading(fileURL){success in
                guard isCurrent() else{return}
                if success{reply("openApp")}else if let view=target{
                    reply("failed")
                    IncidentNotice.attach(to:view,incident:ErrorFeedback.capture(.link,scope:UUID(uuidString:generation)),recoveryTitle:"Open in FluxMarkdown",recovery:openApp)
                }
            }}
            openApp();return
        }
        func chooseDestination() {
            guard isCurrent(),let view=target else{reply("cancelled");return}
            let panel=NSSavePanel();panel.nameFieldStringValue="Diagram."+request.action;panel.allowedFileTypes=[request.action]
            if let window=view.window{panel.beginSheetModal(for:window){result in if result == .OK{run(panel.url)}else{reply("cancelled")}}}
            else if panel.runModal() == .OK{run(panel.url)}else{reply("cancelled")}
        }
        func run(_ destination:URL?) {
            guard isCurrent() else{reply("cancelled");return}
            service.perform(request,destination:destination){result in
                switch result {
                case .success(let status):if isCurrent(){notice?.removeFromSuperview()};reply(status)
                case .failure(let error):
                    reply("failed")
                    guard isCurrent(),let view=target else{return}
                    let incident=ErrorFeedback.capture(.diagramExport,error:error,scope:UUID(uuidString:generation))
                    let invalid=(error as NSError).domain=="DiagramExport" && (error as NSError).code==1
                    let title=invalid ? "Reload File" : request.action=="copy" ? "Try Again" : "Choose Another Folder"
                    IncidentNotice.attach(to:view,incident:incident,recoveryTitle:title,recovery:{
                        if invalid{reload()}else if request.action=="copy"{run(nil)}else{chooseDestination()}
                    })
                    notice=view.subviews.compactMap{$0 as? IncidentNotice}.last
                }
            }
        }
        if request.action=="copy"{run(nil)}else{chooseDestination()}
    }
}
