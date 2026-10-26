# One-click search launch

The user requested a short double-click hint and asked for the search icon to open
the app, current file and search in one operation. This steers the earlier approved
helper feasibility trial toward a launch-only service, with no Accessibility
permission, keyboard interception or persistence.

## Acceptance before implementation

- Failure hint: “双击打开文件后，按 ⌘F 搜索。” with equivalent translations.
- The service is sandboxed and embedded inside the preview extension; it uses public
  XPC/NSWorkspace APIs and starts only for an explicit search action.
- It accepts only authenticated calls from this containing preview executable and
  only valid local-file search requests; it cannot choose another destination app.
- The main app opens the selected document, shows/focuses search and accepts typing
  on cold and warm starts. Default-editor handlers remain unchanged.
- Failure/timeouts display the short hint and leave no unusable inline input.
- Do not retain a production broker merely because mock tests pass: real Finder
  verification must demonstrate an app launch and typed Alpha with count 1/2.

The previous direct calls returned NSOSStatus -54. A primary developer reproduction
documents Quick Look's missing `allow lsopen` sandbox rule:
https://github.com/sbarex/QLTest/blob/master/README.md . This is motivation for testing
a separate standard-sandbox service, not proof that the service will succeed.

## Verified results

- The policy tests failed before implementation. 28 related native policy, URL,
  search and toolbar tests now pass.
- An XPC service inside the extension, with a separate standard App Sandbox
  profile, successfully opened the containing app through NSWorkspace. The preview
  retains its original sandbox; no extra exception, global input API or TCC request
  was introduced. Authenticated calls are restricted to the installed preview
  executable and a validated own-app local document search URI.
- Actual Finder Space → search button started the service and main app, opened
  acceptance-all.md and focused Search query. Direct keyboard typing of Alpha
  produced 1/2. Repeated button actions reused the same app process and preserved
  the current query; the test compared snapshots without overwriting the query.
- Release build and release-entitlement validation passed. The service has exactly
  sandbox=true and user-selected.read-only=true; the release checker enforces that
  allowlist and absence of development extras. A Release-configured acceptance
  candidate repeated the cold-start Finder/button/typed-Alpha test successfully.
- Installed candidate: `1.34.475-dev-20261009-130106`. Existing per-type editor
  handlers are unchanged. The hint is “双击打开文件后，按 ⌘F 搜索。” (five locales).
- The service is launch-on-demand, has no login registration and invalidates the
  client connection after reply/error/timeout. XPC process idle caching is managed
  by macOS; it has no keyboard listener or persistent monitoring job.

This completes the button's one-click route. Finder Cmd+F and inline Quick Look
input remain separate unresolved behavior; no issue is marked released or done.

The final lifecycle cleanup clears connection handlers before invalidation to avoid
retaining completed clients. Delivered Release-configured candidate:
`1.34.475-dev-20261009-130822`. Its release entitlement/signature check, installer and
compressed-image verification passed; the standalone keyboard probe is not embedded.


## 2026-10-26 telemetry extension

The historical launch-only scope above now also includes a parameterless
`flushUsage` operation for active Quick Look sessions. The same authenticated
peer gate remains. Helper entitlements add client networking and read/write access
only to the Telemetry state directory, enforced by release verification. This is
necessary because the preview host blocks direct DNS. See
`DEBUG_QUICKLOOK_TELEMETRY_TRANSPORT.md` for actual installed-host validation.
