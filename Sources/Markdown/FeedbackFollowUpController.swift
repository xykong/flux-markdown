import AppKit
import SwiftUI
import UserNotifications

/// Main-thread owner. No credentials, GitHub mail dependency, or background daemon.
final class FeedbackFollowUpController: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = FeedbackFollowUpController()
    @Published private(set) var state = FeedbackFollowUpState()
    @Published private(set) var status = ""
    private let now: () -> Date
    private let file: URL
    private var timer: Timer?
    private var syncing = false
    private var historyUnavailable = false
    private var nextCheck = Date.distantPast
    private var rateLimitUntil = Date.distantPast
    private var window: NSWindow?
    private var notified: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "feedback.notifiedReplies") ?? []) }
        set { UserDefaults.standard.set(Array(newValue.suffix(1000)), forKey: "feedback.notifiedReplies") }
    }
    private var cache: [String: (String?, Data)] = [:]
    private let openURL: (URL) -> Bool
    private let session: URLSession
    private let systemNotificationsAvailable: Bool
    private var enabled: Bool { UserDefaults.standard.bool(forKey: "feedback.followReplies") }
    var unreadCount: Int { state.unread.count }
    init(file: URL = SharedPreferenceStore.applicationSupportDirectory().appendingPathComponent("feedback-follow-up.json"), session: URLSession = URLSession(configuration: .ephemeral), openURL: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) }, now: @escaping () -> Date = Date.init) {
        self.file = file; self.session = session; self.openURL = openURL; self.now = now
        self.systemNotificationsAvailable = Bundle.main.bundleIdentifier == "com.xykong.Markdown"
        super.init()
        UserDefaults.standard.register(defaults: ["feedback.followReplies": true])
        if FileManager.default.fileExists(atPath: file.path) {
            do { state = try FeedbackFollowUpState.load(from: file) }
            catch { historyUnavailable = true; status = ErrorFeedback.text("Feedback history could not be loaded. Your reports have not been overwritten.") }
        }
    }
    func start() {
        if systemNotificationsAvailable { UNUserNotificationCenter.current().delegate = self }
        NSApp?.dockTile.badgeLabel = unreadCount > 0 ? String(unreadCount) : nil
        timer = Timer.scheduledTimer(withTimeInterval: 300 + Double.random(in: 0...30), repeats: true) { [weak self] _ in self?.refresh() }
        refresh()
    }
    func register(_ incident: ErrorIncident) {
        guard enabled else { return }
        state.register(incident: incident.id, date: incident.date); persist(); refresh(force: true)
    }
    func enable(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "feedback.followReplies")
        if value { refresh(force: true) }
    }
    func askNotifications() {
        guard systemNotificationsAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }
    @discardableResult private func persist() -> Bool {
        // Never replace an unreadable history with an empty state.
        if historyUnavailable { return false }
        do { try state.save(to: file) }
        catch { status = ErrorFeedback.text("Could not save feedback reminders. Keep this window open and try again."); return false }
        NSApp?.dockTile.badgeLabel = unreadCount > 0 ? String(unreadCount) : nil
        return true
    }
    func open(_ item: FeedbackUnreadReply) {
        if state.activate(item, open: openURL) {
            persist()
            // Only this activated comment is acknowledged. Dismissing a banner never calls this path.
            if systemNotificationsAvailable { UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["issue-\(item.issue.number)"]); notifyNewReplies() }
        } else { status = ErrorFeedback.text("Could not open the reply. Try again or copy its link.") }
    }
    func link(_ input: String, incident: UUID) {
        guard let url = URL(string: input.trimmingCharacters(in: .whitespacesAndNewlines)), let number = FeedbackIssue.number(from: url) else {
            status = ErrorFeedback.text("Paste a FluxMarkdown GitHub Issue link."); return
        }
        Task { @MainActor in
            do {
                let data = try await fetch("issues/\(number)")
                guard let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any], raw["pull_request"] == nil, let issue = Self.issue(raw) else { throw FeedbackStateError.association }
                try state.associate(incident: incident, candidates: [issue], manual: true); persist(); refresh(force: true)
            } catch { status = ErrorFeedback.text("Could not verify this Issue. Check the link and try again.") }
        }
    }
    func refresh(force: Bool = false) {
        guard enabled, !syncing, now() >= rateLimitUntil, force || now() >= nextCheck else { return }
        guard !state.reports.isEmpty else { return }
        syncing = true; nextCheck = now().addingTimeInterval(60)
        Task { @MainActor in
            defer { syncing = false }
            do {
                if let oldest = state.reports.filter({ $0.issue == nil }).map(\.date).min() {
                    let since = ISO8601DateFormatter().string(from: oldest.addingTimeInterval(-300))
                    let raw = try await pages("issues?state=all&sort=updated&direction=desc&since=\(since)")
                    guard enabled else { return }
                    let issues = raw.filter { $0["pull_request"] == nil }.compactMap(Self.issue)
                    for report in state.reports where report.issue == nil {
                        // No match/ambiguous match stays pending; retain manual-link recovery.
                        try? state.associate(incident: report.incident, candidates: issues)
                    }
                }
                for report in state.reports {
                    guard enabled else { return }
                    guard let issue = report.issue else { continue }
                    // Recheck the last timestamp inclusively. Stable IDs remove repeats;
                    // failed pagination does not merge a partial response.
                    let sinceDate = report.replies.last?.createdAt ?? issue.createdAt
                    let since = ISO8601DateFormatter().string(from: sinceDate.addingTimeInterval(-1))
                    let raw = try await pages("issues/\(issue.number)/comments?since=\(since)")
                    guard enabled else { return }
                    state.merge(number: issue.number, replies: raw.compactMap(Self.reply))
                }
                let saved = persist(); notifyNewReplies()
                if saved { status = ErrorFeedback.text("Replies checked. Unread reminders stay until you click them.") }
                nextCheck = now().addingTimeInterval(300)
            } catch {
                status = ErrorFeedback.text("Could not check replies. Existing reminders are preserved; checking will resume later.")
                nextCheck = max(nextCheck, now().addingTimeInterval(300))
            }
        }
    }
    private func pages(_ path: String) async throws -> [[String: Any]] {
        var all: [[String: Any]] = []
        for page in 1...20 {
            let separator = path.contains("?") ? "&" : "?"
            let data = try await fetch(path + separator + "per_page=100&page=\(page)")
            guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { throw FeedbackStateError.invalidData }
            all.append(contentsOf: rows)
            if rows.count < 100 { return all }
        }
        throw FeedbackStateError.invalidData // bounded scan, never silently skip a remaining page
    }
    private func fetch(_ path: String) async throws -> Data {
        guard let url = URL(string: "https://api.github.com/repos/xykong/flux-markdown/" + path) else { throw FeedbackStateError.invalidData }
        var request = URLRequest(url: url); request.timeoutInterval = 20
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("FluxMarkdown-Feedback", forHTTPHeaderField: "User-Agent")
        if let etag = cache[path]?.0 { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        let (data, response): (Data, URLResponse) = try await withCheckedThrowingContinuation { continuation in
            session.dataTask(with: request) { data, response, error in
                if let error { continuation.resume(throwing: error) }
                else if let data, let response { continuation.resume(returning: (data, response)) }
                else { continuation.resume(throwing: FeedbackStateError.invalidData) }
            }.resume()
        }
        guard let http = response as? HTTPURLResponse else { throw FeedbackStateError.invalidData }
        if http.statusCode == 304, let previous = cache[path] { return previous.1 }
        if http.statusCode == 403 || http.statusCode == 429 {
            let reset = http.value(forHTTPHeaderField: "X-RateLimit-Reset").flatMap(Double.init).map { Date(timeIntervalSince1970: $0) }
            let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init).map { now().addingTimeInterval($0) }
            rateLimitUntil = max(rateLimitUntil, retry ?? reset ?? now().addingTimeInterval(900))
            nextCheck = max(nextCheck, rateLimitUntil)
        }
        guard http.statusCode == 200, data.count <= 4 * 1024 * 1024 else { throw FeedbackStateError.invalidData }
        if cache.count >= 100 { cache.removeAll() }
        cache[path] = (http.value(forHTTPHeaderField: "ETag"), data)
        return data
    }
    private static func date(_ value: Any?) -> Date? { (value as? String).flatMap { ISO8601DateFormatter().date(from: $0) } }
    private static func issue(_ raw: [String: Any]) -> FeedbackIssue? {
        guard let number = raw["number"] as? Int, number > 0, let title = raw["title"] as? String,
              let author = (raw["user"] as? [String: Any])?["login"] as? String, let created = date(raw["created_at"]) else { return nil }
        return FeedbackIssue(number: number, title: String(title.prefix(500)), body: raw["body"] as? String ?? "", author: author, createdAt: created)
    }
    private static func reply(_ raw: [String: Any]) -> FeedbackReply? {
        guard let id = raw["id"] as? Int64, id > 0, let author = (raw["user"] as? [String: Any])?["login"] as? String,
              let created = date(raw["created_at"]) else { return nil }
        return FeedbackReply(id: id, author: author, body: String((raw["body"] as? String ?? "").prefix(4000)), createdAt: created)
    }
    private func notifyNewReplies() {
        guard systemNotificationsAvailable, enabled else { return }
        let grouped = Dictionary(grouping: state.unread, by: { $0.issue.number })
        for items in grouped.values {
            guard let item = items.first, let latest = items.last, !notified.contains(latest.id) else { continue }
            var sent = notified; sent.insert(latest.id); notified = sent
            let content = UNMutableNotificationContent()
            content.title = "FluxMarkdown · #\(item.issue.number)"
            content.body = ErrorFeedback.text("Your Issue has a new reply. Click to open it.")
            content.userInfo = ["reply": item.id]
            content.threadIdentifier = "issue-\(item.issue.number)"
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "issue-\(item.issue.number)", content: content, trigger: nil))
        }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier, let id = response.notification.request.content.userInfo["reply"] as? String {
            DispatchQueue.main.async { [weak self] in
                defer { completionHandler() }
                guard let self, let item = self.state.unread.first(where: { $0.id == id }) else { return }
                self.open(item)
            }
        } else { completionHandler() }
    }
    func show() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 650, height: 540), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = ErrorFeedback.text("My Feedback"); window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: FeedbackFollowUpView(controller: self)); window.center(); self.window = window
        }
        NSApp.activate(ignoringOtherApps: true); window?.makeKeyAndOrderFront(nil); refresh(force: true)
    }
}
private struct FeedbackFollowUpView: View {
    @ObservedObject var controller: FeedbackFollowUpController
    @State private var following = UserDefaults.standard.bool(forKey: "feedback.followReplies")
    @State private var links: [UUID: String] = [:]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(ErrorFeedback.text("My Feedback")).font(.title2)
            Toggle(ErrorFeedback.text("Check my submitted Issues for replies"), isOn: $following).onChange(of: following) { controller.enable($0) }
            Text(ErrorFeedback.text("Checks public GitHub Issues while FluxMarkdown is running. Replies missed while offline are checked next time. Unread markers clear only when you click a reply.")).font(.caption)
            HStack {
                Button(ErrorFeedback.text("Check Now")) { controller.refresh(force: true) }
                Button(ErrorFeedback.text("Enable System Notifications…")) { controller.askNotifications() }
            }
            Text(controller.status).font(.caption)
            List {
                ForEach(controller.state.unread) { item in
                    VStack(alignment: .leading) {
                        Button("● #\(item.issue.number) · @\(item.reply.author)") { controller.open(item) }
                        Text(item.reply.body).lineLimit(3)
                        Button(ErrorFeedback.text("Copy Link")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(item.url.absoluteString, forType: .string) }
                    }
                }
                ForEach(controller.state.reports) { report in
                    VStack(alignment: .leading) {
                        if let issue = report.issue {
                            // General Issue links never acknowledge reply reminders.
                            Link("#\(issue.number) · \(issue.title)", destination: issue.url)
                        } else {
                            Text(ErrorFeedback.text("Waiting to find the submitted Issue"))
                            Text(report.incident.uuidString).font(.caption)
                            HStack {
                                TextField(ErrorFeedback.text("Paste Issue link"), text: Binding(get: { links[report.incident] ?? "" }, set: { links[report.incident] = $0 }))
                                Button(ErrorFeedback.text("Link Issue")) { controller.link(links[report.incident] ?? "", incident: report.incident) }
                            }
                        }
                    }
                }
            }
        }.padding(20).frame(minWidth: 580, minHeight: 440)
        .interfaceLayoutDirection(for: AppearancePreference.shared.uiLanguage)
    }
}
