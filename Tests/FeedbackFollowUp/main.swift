import Foundation

func check(_ value: @autoclosure () -> Bool, _ message: String) { if !value() { fatalError(message) } }
let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: root) }
let url = root.appendingPathComponent("state.json")
let incident = UUID()
let time = Date(timeIntervalSince1970: 100)
var state = FeedbackFollowUpState()
state.register(incident: incident, date: time)
let issue = FeedbackIssue(number: 73, title: "Math", body: "Incident: \(incident.uuidString)", author: "reporter", createdAt: time)
try state.associate(incident: incident, candidates: [issue])
let first = FeedbackReply(id: 11, author: "maintainer", body: "Please share a sample", createdAt: time.addingTimeInterval(10))
let second = FeedbackReply(id: 12, author: "other", body: "Same here", createdAt: time.addingTimeInterval(20))
state.merge(number: 73, replies: [second, first, first, FeedbackReply(id: 13, author: "reporter", body: "My own reply", createdAt: time.addingTimeInterval(30))])
check(state.unread.count == 2, "stable IDs deduplicate; own replies excluded; delayed association retains replies")
try state.save(to: url)
state = try FeedbackFollowUpState.load(from: url)
check(state.unread.map(\.reply.id) == [11, 12], "unread survives restart in chronological order")
let clicked = state.unread[0]
check(!state.activate(clicked, open: { _ in false }), "failed navigation")
check(state.unread.count == 2, "failure preserves marker")
let third = FeedbackReply(id: 14, author: "maintainer", body: "More", createdAt: time.addingTimeInterval(40))
check(state.activate(clicked, open: { target in
    check(target.absoluteString == "https://github.com/xykong/flux-markdown/issues/73#issuecomment-11", "exact fixed repo comment")
    return true
}), "explicit activation")
state.merge(number: 73, replies: [third])
check(state.unread.map(\.reply.id) == [12, 14], "only clicked item clears; new replies stay unread")
check(FeedbackIssue.number(from: URL(string: "https://github.com/evil/repo/issues/73")!) == nil, "reject foreign issue")
check(FeedbackIssue.number(from: URL(string: "https://github.com/xykong/flux-markdown/issues/73")!) == 73, "manual issue link")
var ambiguous = FeedbackFollowUpState(); ambiguous.register(incident: incident, date: time)
do { try ambiguous.associate(incident: incident, candidates: [issue, FeedbackIssue(number: 74, title: "Other", body: issue.body, author: "reporter", createdAt: time)]); fatalError("ambiguous association accepted") } catch { }
check(ambiguous.reports.first?.issue == nil, "ambiguous report remains pending")
let foreignBody = FeedbackIssue(number: 75, title: "Wrong", body: "Incident: \(incident.uuidString)00", author: "r", createdAt: time)
do { try ambiguous.associate(incident: incident, candidates: [foreignBody]); fatalError("prefix matched") } catch { }

let document = root.appendingPathComponent("original.md")
try "# Hello\n\n![x](image.png)".write(to: document, atomically: true, encoding: .utf8)
let image = root.appendingPathComponent("image.png")
try Data([1, 2, 3]).write(to: image)
let snapshot = try FeedbackReproduction.document(document)
check(snapshot.source == "# Hello\n\n![x](image.png)", "source preserved")
let bundle = try FeedbackReproduction.prepare(source: snapshot.source, mode: "document", diagnostics: "safe", incident: incident, originalURL: document, resources: [image])
check(bundle.entries.contains { $0.name == "document.md" }, "neutral document filename")
check(bundle.entries.contains { $0.name == "image.png" }, "relative resource layout retained")
let zip = root.appendingPathComponent("report.zip")
try bundle.writeZIP(to: zip)
let zipData = try Data(contentsOf: zip)
check(zipData.prefix(2) == Data([0x50,0x4b]), "valid ZIP header")
let outsider = root.appendingPathComponent("unreferenced.png"); try Data([0]).write(to: outsider)
do { _ = try FeedbackReproduction.prepare(source: snapshot.source, mode: "document", diagnostics: "", incident: incident, originalURL: document, resources: [outsider]); fatalError("unreferenced accepted") } catch { }
let link = root.appendingPathComponent("link.png"); try FileManager.default.createSymbolicLink(at: link, withDestinationURL: image)
do { _ = try FeedbackReproduction.prepare(source: "![x](link.png)", mode: "document", diagnostics: "", incident: incident, originalURL: document, resources: [link]); fatalError("symlink accepted") } catch { }
do { _ = try FeedbackReproduction.prepare(source: String(repeating: "x", count: 20*1024*1024+1), mode: "sample", diagnostics: "", incident: incident); fatalError("oversize accepted") } catch { }
let unchanged = try String(contentsOf: document, encoding: .utf8)
check(unchanged == snapshot.source, "original not modified")
print("PASS feedback association, durable click-only unread, exact links, bounded ZIP and resource selection")
