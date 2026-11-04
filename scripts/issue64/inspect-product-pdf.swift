import Foundation
import PDFKit

guard CommandLine.arguments.count == 2,
      let document = PDFDocument(url: URL(fileURLWithPath: CommandLine.arguments[1])) else {
    fputs("Expected a readable issue-64 PDF path\n", stderr)
    exit(2)
}
var links: [[String: Any]] = []
for index in 0..<document.pageCount {
    guard let page = document.page(at: index) else { exit(1) }
    for annotation in page.annotations where annotation.type == "Link" {
        guard let action = annotation.action as? PDFActionGoTo,
              let targetPage = action.destination.page else {
            fputs("Expected an internal equation-reference destination\n", stderr)
            exit(1)
        }
        let destination = document.index(for: targetPage)
        guard destination != NSNotFound,
              targetPage.bounds(for: .mediaBox).contains(action.destination.point) else {
            fputs("Equation-reference destination is outside the PDF\n", stderr)
            exit(1)
        }
        links.append(["sourcePage": index + 1, "destinationPage": destination + 1,
                      "destinationPoint": [action.destination.point.x, action.destination.point.y]])
    }
}
guard document.pageCount == 2, links.count == 1,
      links[0]["sourcePage"] as? Int == 2, links[0]["destinationPage"] as? Int == 2 else {
    fputs("Issue-64 PDF page or equation-reference structure changed\n", stderr)
    exit(1)
}
let data = try JSONSerialization.data(withJSONObject: ["pages": document.pageCount, "internalLinks": links], options: [.prettyPrinted, .sortedKeys])
print(String(decoding: data, as: UTF8.self))
