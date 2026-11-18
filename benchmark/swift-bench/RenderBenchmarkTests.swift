/**
 * Layer 2: Swift / WKWebView Rendering Benchmark
 *
 * Measures:
 *   T2: evaluateJavaScript(renderMarkdown) round-trip (Swift → JS → Swift callback)
 *   T5: collectImageData() duration (synchronous image base64 encoding, main thread)
 *   T_webview_init: WKWebView load + rendererReady handshake
 *
 * Run via:
 *   xcodebuild test -project FluxMarkdown.xcodeproj \
 *     -scheme Markdown -destination 'platform=macOS,arch=arm64' \
 *     -only-testing MarkdownTests/RenderBenchmarkTests \
 *     2>&1 | tee benchmark/results/swift-bench-raw.log
 *
 * Results are written to benchmark/results/swift-bench-TIMESTAMP.json
 */

import XCTest
import WebKit

// MARK: - Timing helpers

private struct TimingSample {
    let runType: String       // "cold" | "warm"
    let iteration: Int
    let t_js_roundtrip_ms: Double
    let t_collect_image_ms: Double
    let html_length: Int
    let fixture: String
}

private func stats(_ samples: [Double]) -> [String: Double] {
    guard !samples.isEmpty else { return [:] }
    let sorted = samples.sorted()
    let n = sorted.count
    let mean = samples.reduce(0, +) / Double(n)
    let variance = samples.reduce(0) { $0 + pow($1 - mean, 2) } / Double(n - 1)
    let stddev = sqrt(variance)
    func pct(_ p: Int) -> Double { sorted[min(Int(ceil(Double(p) / 100 * Double(n))) - 1, n - 1)] }
    return [
        "n": Double(n),
        "mean": mean,
        "median": pct(50),
        "p95": pct(95),
        "p99": pct(99),
        "min": sorted[0],
        "max": sorted[n - 1],
        "stddev": stddev,
        "cv": mean > 0 ? stddev / mean : 0,
    ]
}

// MARK: - BenchmarkWebViewHarness

/// Minimal WKWebView harness that replicates the real rendering pipeline
/// (both QuickLook and MainApp paths share the same JS bridge and collectImageData logic).
@MainActor
class BenchmarkWebViewHarness: NSObject, WKNavigationDelegate, WKScriptMessageHandler {

    private static let sharedProcessPool = WKProcessPool()

    private(set) var webView: WKWebView!
    private var rendererReadyContinuation: CheckedContinuation<Void, Error>?
    private var renderContinuation: CheckedContinuation<(Double, Int), Error>?
    private var renderStartTime: CFAbsoluteTime = 0
    private var readyAttempt = UUID()

    override init() {
        super.init()
        let config = WKWebViewConfiguration()
        config.processPool = Self.sharedProcessPool
        let ucc = WKUserContentController()
        ucc.add(self, name: "logger")
        ucc.add(self, name: "benchResult")
        config.userContentController = ucc
        if let root = findIndexHTML()?.deletingLastPathComponent() {
            config.setURLSchemeHandler(RendererBundleSchemeHandler(rootDirectory: root),
                                       forURLScheme: RendererBundleSchemeHandler.scheme)
        }
        if #available(macOS 11.0, *) {
            let prefs = WKWebpagePreferences()
            prefs.allowsContentJavaScript = true
            config.defaultWebpagePreferences = prefs
        }
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1200, height: 800), configuration: config)
        webView.navigationDelegate = self
    }

    /// Use the same scheme as production so split JS/CSS/WASM assets can load.
    func loadAndWaitForReady() async throws {
        guard findIndexHTML() != nil else {
            throw NSError(domain: "Benchmark", code: 1, userInfo: [NSLocalizedDescriptionKey: "index.html not found"])
        }
        return try await withCheckedThrowingContinuation { continuation in
            rendererReadyContinuation = continuation
            readyAttempt = UUID()
            let attempt = readyAttempt
            webView.load(URLRequest(url: RendererBundleSchemeHandler.rendererURL()))
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
                guard let self, self.readyAttempt == attempt,
                      let pending = self.rendererReadyContinuation else { return }
                self.rendererReadyContinuation = nil
                pending.resume(throwing: NSError(domain: "Benchmark", code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "Renderer handshake exceeded 15 seconds"]))
            }
        }
    }

    func dispose() {
        webView.stopLoading()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "logger")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "benchResult")
        webView.navigationDelegate = nil
    }

    private func findIndexHTML() -> URL? {
        let bundle = Bundle(for: BenchmarkWebViewHarness.self)
        return bundle.url(forResource: "index", withExtension: "html", subdirectory: "WebRenderer")
            ?? bundle.url(forResource: "index", withExtension: "html", subdirectory: "dist")
            ?? bundle.url(forResource: "index", withExtension: "html")
    }

    /// Render markdown and return (roundtrip_ms, html_length).
    /// The JS side must call window.webkit.messageHandlers.benchResult.postMessage(...)
    /// to report completion. We inject a thin wrapper around renderMarkdown.
    func renderMarkdown(_ content: String, options: [String: Any] = [:]) async throws -> (Double, Int) {
        guard let contentData = try? JSONSerialization.data(withJSONObject: [content]),
              let contentJsonArray = String(data: contentData, encoding: .utf8) else {
            throw NSError(domain: "Benchmark", code: 2, userInfo: [NSLocalizedDescriptionKey: "JSON encode failed"])
        }
        let safeContent = String(contentJsonArray.dropFirst().dropLast())

        var opts = options
        opts["theme"] = "light"
        guard let optsData = try? JSONSerialization.data(withJSONObject: opts),
              let optsJson = String(data: optsData, encoding: .utf8) else {
            throw NSError(domain: "Benchmark", code: 3, userInfo: [NSLocalizedDescriptionKey: "Options encode failed"])
        }

        // Inject timing wrapper on first call
        let setupJS = """
        (function() {
            if (!window.__benchWrapInstalled) {
                window.__benchWrapInstalled = true;
                const _orig = window.renderMarkdown.bind(window);
                window.__benchRender = async function(text, opts) {
                    const t0 = performance.now();
                    await _orig(text, opts);
                    const t1 = performance.now();
                    const htmlLen = document.getElementById('markdown-preview')?.innerHTML?.length ?? 0;
                    window.webkit.messageHandlers.benchResult.postMessage(
                        JSON.stringify({ duration_ms: t1 - t0, html_length: htmlLen })
                    );
                };
            }
        })();
        """
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            webView.evaluateJavaScript(setupJS) { _, error in
                if let error = error { cont.resume(throwing: error) } else { cont.resume() }
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            renderContinuation = continuation
            renderStartTime = CFAbsoluteTimeGetCurrent()
            let js = "window.__benchRender(\(safeContent), \(optsJson)); undefined;"
            webView.evaluateJavaScript(js) { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    self.renderContinuation = nil
                }
            }
        }
    }

    // MARK: - WKScriptMessageHandler

    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        Task { @MainActor in
            if message.name == "logger", let body = message.body as? String {
                if body == "rendererReady" {
                    rendererReadyContinuation?.resume(returning: ())
                    rendererReadyContinuation = nil
                }
            } else if message.name == "benchResult", let body = message.body as? String {
                guard let data = body.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let durationMs = json["duration_ms"] as? Double,
                      let htmlLength = json["html_length"] as? Int else { return }
                renderContinuation?.resume(returning: (durationMs, htmlLength))
                renderContinuation = nil
            }
        }
    }

    // MARK: - WKNavigationDelegate failure reporting

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            rendererReadyContinuation?.resume(throwing: error)
            rendererReadyContinuation = nil
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation nav: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            rendererReadyContinuation?.resume(throwing: error)
            rendererReadyContinuation = nil
        }
    }
}

// MARK: - RenderBenchmarkTests

@MainActor
final class RenderBenchmarkTests: XCTestCase {

    // Configuration
    let warmupRuns = 3
    let benchRuns = 10
    let coldRuns = 3    // full WebView teardown + reload between runs

    var fixturesDir: URL {
        let env = ProcessInfo.processInfo.environment
        if let srcRoot = env["TEST_RUNNER_SRCROOT"] ?? env["SRCROOT"] {
            let candidate = URL(fileURLWithPath: srcRoot).appendingPathComponent("benchmark/fixtures")
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        var url = URL(fileURLWithPath: #file)
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        return url.appendingPathComponent("fixtures")
    }

    var resultsDir: URL {
        fixturesDir.deletingLastPathComponent().appendingPathComponent("results")
    }

    // MARK: - Tests

    func testBenchmarkAllFixtures() async throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fixturesDir.path) else {
            XCTFail("Fixtures directory not found: \(fixturesDir.path)")
            return
        }

        let fixtures = try fm.contentsOfDirectory(at: fixturesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        XCTAssertFalse(fixtures.isEmpty, "No fixture files found in \(fixturesDir.path)")

        var allResults: [[String: Any]] = []

        for fixture in fixtures {
            let result = try await benchmarkFixture(fixture)
            allResults.append(result)
            printFixtureSummary(result)
        }

        try saveResults(allResults)
    }

    // MARK: - Benchmark a single fixture

    private func benchmarkFixture(_ fixturePath: URL) async throws -> [String: Any] {
        let fixtureName = fixturePath.lastPathComponent
        let content = try String(contentsOf: fixturePath, encoding: .utf8)
        let contentLengthKB = Double(content.utf8.count) / 1024.0

        print("\n  📄 \(fixtureName) (\(String(format: "%.1f", contentLengthKB)) KB)")

        var coldRoundtripSamples: [Double] = []
        var warmRoundtripSamples: [Double] = []
        var coldCollectSamples: [Double] = []
        var warmCollectSamples: [Double] = []

        // ── T5: collectImageData (Swift-side, no images in most fixtures) ──
        // Measure directly since it's pure Swift
        let t5_ms = measureCollectImageData(content: content, fileURL: fixturePath)
        coldCollectSamples.append(contentsOf: Array(repeating: t5_ms, count: coldRuns))
        warmCollectSamples.append(contentsOf: Array(repeating: t5_ms, count: benchRuns))

        // ── COLD: new WKWebView per run ────────────────────────────────────
        print("     Cold runs (\(coldRuns))...")
        for i in 0..<coldRuns {
            let harness = BenchmarkWebViewHarness()
            defer { harness.dispose() }
            try await harness.loadAndWaitForReady()

            let (duration, _) = try await harness.renderMarkdown(content)
            coldRoundtripSamples.append(duration)
            print("     [cold-\(i)] T2=\(String(format: "%.1f", duration))ms")
        }

        // ── WARM: same WKWebView, multiple renders ──────────────────────────
        print("     Warm runs (\(warmupRuns) warmup + \(benchRuns) measured)...")
        let warmHarness = BenchmarkWebViewHarness()
        defer { warmHarness.dispose() }
        try await warmHarness.loadAndWaitForReady()

        for i in 0..<warmupRuns {
            let (dur, _) = try await warmHarness.renderMarkdown(content)
            print("     [warmup-\(i)] T2=\(String(format: "%.1f", dur))ms")
        }

        for i in 0..<benchRuns {
            let (duration, htmlLen) = try await warmHarness.renderMarkdown(content)
            warmRoundtripSamples.append(duration)
            print("     [warm-\(i)] T2=\(String(format: "%.1f", duration))ms html=\(htmlLen/1024)KB")
        }

        return [
            "fixture": fixtureName,
            "content_length_kb": contentLengthKB,
            "cold": [
                "t2_roundtrip": stats(coldRoundtripSamples),
                "t5_collect_image": stats(coldCollectSamples),
            ],
            "warm": [
                "t2_roundtrip": stats(warmRoundtripSamples),
                "t5_collect_image": stats(warmCollectSamples),
            ],
        ]
    }

    // MARK: - T5: collectImageData measurement

    private func measureCollectImageData(content: String, fileURL: URL) -> Double {
        // Replicate the real collectImageData logic to measure its cost
        let regex = try? NSRegularExpression(pattern: #"!\[[^\]]*\]\(([^)"]+(?:\s+"[^"]*")?)\)"#)
        let baseDir = fileURL.deletingLastPathComponent()

        let start = CFAbsoluteTimeGetCurrent()

        let nsContent = content as NSString
        let matches = regex?.matches(in: content, range: NSRange(location: 0, length: nsContent.length)) ?? []

        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }
            var imagePath = nsContent.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)

            if imagePath.starts(with: "http://") || imagePath.starts(with: "https://") || imagePath.starts(with: "data:") {
                continue
            }

            if let spaceIdx = imagePath.firstIndex(of: " "), imagePath[spaceIdx...].contains("\"") {
                imagePath = String(imagePath[..<spaceIdx])
            }

            var imageURL: URL
            if imagePath.starts(with: "/") {
                imageURL = URL(fileURLWithPath: imagePath)
            } else {
                if imagePath.starts(with: "./") { imagePath = String(imagePath.dropFirst(2)) }
                imageURL = baseDir
                for component in imagePath.split(separator: "/") {
                    if component == ".." { imageURL.deleteLastPathComponent() }
                    else { imageURL.appendPathComponent(String(component)) }
                }
            }

            if let data = try? Data(contentsOf: imageURL) {
                _ = data.base64EncodedString()
            }
        }

        let end = CFAbsoluteTimeGetCurrent()
        return (end - start) * 1000.0
    }

    // MARK: - Output helpers

    private func printFixtureSummary(_ result: [String: Any]) {
        guard let fixture = result["fixture"] as? String,
              let cold = result["cold"] as? [String: Any],
              let warm = result["warm"] as? [String: Any],
              let coldT2 = cold["t2_roundtrip"] as? [String: Double],
              let warmT2 = warm["t2_roundtrip"] as? [String: Double] else { return }

        print(String(format: "  %@ cold p50=%.1fms p95=%.1fms  warm p50=%.1fms p95=%.1fms",
                     fixture as NSString,
                     coldT2["median"] ?? 0,
                     coldT2["p95"] ?? 0,
                     warmT2["median"] ?? 0,
                     warmT2["p95"] ?? 0))
    }

    private func saveResults(_ results: [[String: Any]]) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: resultsDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())

        let report: [String: Any] = [
            "meta": [
                "layer": "swift",
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "warmup_runs": warmupRuns,
                "bench_runs": benchRuns,
                "cold_runs": coldRuns,
                "os_version": ProcessInfo.processInfo.operatingSystemVersionString,
                "process_count": ProcessInfo.processInfo.processorCount,
            ],
            "results": results,
        ]

        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])

        let outURL = resultsDir.appendingPathComponent("swift-bench-\(timestamp).json")
        try data.write(to: outURL)

        let latestURL = resultsDir.appendingPathComponent("swift-bench-latest.json")
        try data.write(to: latestURL)

        print("\n  ✅ Swift benchmark results saved to:")
        print("     \(outURL.path)")
        print("     \(latestURL.path) (latest)")
    }
}
