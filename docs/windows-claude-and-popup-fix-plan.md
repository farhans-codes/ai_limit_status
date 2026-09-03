# AI Limit Status — Windows fix plan

Scope: two Windows bug reports against v0.7.0 (`8bb7719`).

1. Claude usage never appears in the taskbar overlay (only Codex `45` is shown).
2. Left-clicking the taskbar indicators does not open the details popup.

The analysis below is from reading the current source, the `window_manager 0.5.2`
/ `screen_retriever_windows 0.2.2` plugin sources, and CodexBar's Claude
provider implementation (`Sources/CodexBarCore/Providers/Claude`).

---

## 1. Why Claude is missing on Windows

### 1.1 What the code does today

`ClaudeUsageReader.read()` (lib/features/usage/data/datasources/claude_usage_reader.dart):

```
credentials = %USERPROFILE%\.claude\.credentials.json  (or CLAUDE_CONFIG_DIR)
if credentials == null:
    executable = locator.find(claude)
    directIssue = executable == null ? cliNotFound : notSignedIn
payload = null  ->  try _fetchWebUsage()            # browser fallback
    on UsageReadException: throw UsageReadException(directIssue ?? error.issue)
```

`_fetchWebUsage()` on Windows reads the `claude.ai` `sessionKey` through
`readClaudeBrowserSessionKey()` -> MethodChannel `readWindowsBrowserSessions`
-> named pipe `\\.\pipe\AI-Limit-Status-Browser-Session` -> which is only
served while the **opt-in Chrome/Edge/Firefox extension** is loaded and
connected to the native host.

Then `UsageRepositoryImpl.fetchUsage()` does:

```dart
return usages.where((usage) => usage.isInstalled).toList();
```

and `ProviderUsageModel.disconnected()` sets `isInstalled = issue != cliNotFound`.

### 1.2 Root cause (confirmed from code)

On the user's Windows PC:

* Claude Code CLI is not installed (or not signed in), so no
  `.credentials.json` -> `directIssue = cliNotFound`.
* The browser bridge extension has never been loaded ("Load unpacked" is a
  manual developer-mode step), so the pipe does not exist ->
  `_fetchWebUsage()` throws `notSignedIn`.
* The `throw UsageReadException(directIssue ?? error.issue)` line turns that
  into `cliNotFound`, so `isInstalled == false`.
* `UsageRepositoryImpl` silently **drops** the Claude entry. The UI never gets
  a chance to show "Claude: not connected / connect" — it just disappears, and
  the overlay draws a single Codex segment.

So this is two problems stacked:

| # | Problem | Effect |
|---|---------|--------|
| A | Being logged in to claude.ai in a normal browser is **not** a usage source on Windows unless the extension bridge is installed by hand. | No data source ever succeeds. |
| B | A provider whose CLI is absent is filtered out entirely instead of being shown as "not connected". | The user cannot tell why Claude is missing or what to do. |

There is also a latent third problem that will hit as soon as the CLI path is
used:

| C | The app never refreshes the Claude OAuth token. It relies on the user running `claude` so the CLI rewrites `.credentials.json`. Claude Code access tokens are short-lived (hours). | A Windows user who does not run the CLI every day gets `401` -> "unavailable" -> stale/`—`. |

### 1.3 How CodexBar handles the same cases (reference)

From `ClaudeSourcePlanner.swift` / `ClaudeOAuthCredentials.swift` /
`ClaudeWebAPIFetcher.swift`:

* Source order in auto mode: **OAuth -> CLI (PTY `/usage`) -> Web cookies**.
  Each source is tried only if plausibly available, and errors fall through.
* Credentials file: `CLAUDE_CONFIG_DIR` (single literal directory, `~` not
  expanded) else `$HOME/.claude`, plus `CLAUDE_SECURESTORAGE_CONFIG_DIR`;
  file name `.credentials.json`; JSON `claudeAiOauth.{accessToken,
  refreshToken, expiresAt(ms), scopes[], subscriptionType, rateLimitTier}`.
  A missing `expiresAt` is treated as expired. A payload with only `mcpOAuth`
  and no `claudeAiOauth` is treated as "re-authenticate".
* OAuth request (identical to what this app already sends):
  `GET https://api.anthropic.com/api/oauth/usage` with
  `Authorization: Bearer`, `Accept/Content-Type: application/json`,
  `anthropic-beta: oauth-2025-04-20`, `User-Agent: claude-code/<version>`
  (fallback `claude-code/2.1.0`). Client-side gate: `scopes` must contain
  `user:profile`, otherwise tell the user to run `claude setup-token`.
* 429: per-token cooldown of 300 s or `Retry-After`, whichever is later.
* Token refresh, direct:
  `POST https://platform.claude.com/v1/oauth/token`,
  `Content-Type: application/x-www-form-urlencoded`, body
  `grant_type=refresh_token&refresh_token=...&client_id=9d1c250a-e61b-44d9-88ed-5944d1962f5e`;
  response `{access_token, refresh_token?, expires_in}`;
  `invalid_grant` = terminal (sign in again), other 400/401 = back off.
  CodexBar only refreshes credentials it owns; for CLI-owned credentials on
  macOS it "delegates" by launching `claude /status` in a PTY so the CLI
  refreshes its own keychain item. On Windows there is no keychain, the file is
  authoritative, so a direct refresh + write-back (exactly what this project
  already does for Codex `auth.json`) is the sane port.
* Web fallback: `GET https://claude.ai/api/organizations` ->
  pick org with capability `chat`, else first non-API-only, else first ->
  `GET https://claude.ai/api/organizations/{uuid}/usage`. Headers are only
  `Cookie: sessionKey=sk-ant-...` and `Accept: application/json`.
  `403` with `cf-mitigated: challenge` header or "Just a moment" body =
  Cloudflare challenge (VPN/datacenter IP) — do **not** clear the cookie, show a
  specific message. A `Set-Cookie: sessionKey=` on 200 is a rotated key and must
  be persisted. (This app already implements the org selection and rotation the
  same way — good.)
* "Not installed" (binary unresolvable) vs "not signed in"
  (`claude auth status --json` -> `{"loggedIn": false}`) are distinct states and
  both are *shown*, never hidden.

Windows ports of CodexBar and what they do for the browser session:

* Win-CodexBar (Rust/egui) and CodexBar-Win (Python): read Chrome/Edge/Brave
  cookie DBs and decrypt with DPAPI + AES-GCM, with a manual "paste cookie"
  escape hatch. Note: Chrome/Edge 127+ use **App-Bound Encryption** (`v20`
  cookies) which cannot be decrypted from a normal user process, so this route
  is increasingly broken on current browsers. The extension bridge you built is
  the "correct" answer to that — it just has a discoverability/installation
  problem.

### 1.4 Fix plan for Claude on Windows

Ordered by impact; steps 1–3 are the minimum for this bug.

**Step 1 — stop hiding the provider (repository + reader).**

* `UsageRepositoryImpl.fetchUsage()`: do not filter on `isInstalled`. Return
  all providers; let the UI render the `cliNotFound` card (the card widget
  already has copy + an "Install & sign in" action for it, see
  `provider_details_card.dart:504-593`). Keep the "No providers detected"
  empty state only when *every* provider is `cliNotFound` **and** no browser
  session exists.
* `ClaudeUsageReader.read()`: when the web fallback fails, report the most
  *actionable* issue, not `directIssue` blindly. Suggested precedence:
  `notSignedIn` (from either source) > `cliNotFound` > `unavailable`. Add a new
  `UsageConnectionIssue.browserBridgeNotConnected` (or carry a
  `hint` enum) so the card can say "Connect Claude via browser" on Windows.
* `UsageController._updateTray()`: when Claude is present but disconnected,
  pass `claudeValue = l10n.notAvailableCompact` (`—`) so the overlay shows two
  segments (`C 45 | Claude —`). This makes the missing provider visible and
  clickable instead of vanishing. (`DisplayValue()` in the overlay already
  renders a 1-character `—` as-is and an empty value as `--`.)

**Step 2 — make the browser session source usable without developer mode.**

Recommended: an in-app **"Connect claude.ai"** flow using WebView2, which is
present on every Windows 11 machine and most Windows 10 machines:

* Add a hidden-by-default sign-in window (Flutter `flutter_inappwebview`
  — its `CookieManager` lists Windows/WebView2 as supported — or, more robustly,
  a small native window in the runner using the WebView2 C++ SDK via CMake
  `FetchContent`/NuGet). Load `https://claude.ai/login`.
* On navigation to `https://claude.ai/*` after login, read the `sessionKey`
  cookie through the WebView2 cookie manager
  (`CoreWebView2CookieManager::GetCookies("https://claude.ai")`; this returns
  HttpOnly cookies, unlike JS `document.cookie`). Verify it starts with
  `sk-ant-`.
* Hand it to `ClaudeUsageReader` through the existing
  `_cachedWebSessionKey` path (same code as macOS). Persist it encrypted with
  DPAPI (`CryptProtectData`) under `%LOCALAPPDATA%\AI Limit Status\` so it
  survives restarts; the README/PRIVACY already allow "in memory" only, so
  either update the privacy statement or keep it memory-only and re-prompt.
* Expose it as the primary action on the Claude card when no CLI credentials
  exist: **Connect claude.ai** (WebView2) / **Install Claude Code** (winget).
* Keep the extension bridge as a secondary option and surface it in Settings
  with a live status line ("Browser bridge: connected / not detected") using a
  cheap `CallNamedPipe` probe; add an "Open extension folder" button that opens
  `%LOCALAPPDATA%\Programs\AI Limit Status\browser_extension\chromium` so the
  "Load unpacked" step is one click away. Longer term, publish the extension
  to the Chrome Web Store and pin the ID (`hiegdhoebaalcbjijlfbcdkdfokennap`).
* Advanced escape hatch (Settings -> Advanced): paste a `sessionKey` or a
  `claude setup-token` OAuth token. CodexBar and both Windows ports offer this;
  it costs almost nothing and unblocks users on locked-down machines.

**Step 3 — Windows OAuth token refresh (mirror the Codex reader).**

* Parse `expiresAt`, `refreshToken`, `scopes` from `.credentials.json`.
* If `now > expiresAt - 5 min` and a refresh token exists, POST to
  `https://platform.claude.com/v1/oauth/token` as in §1.3, then write the
  rotated `accessToken`/`refreshToken`/`expiresAt` back into the same file
  (preserve `scopes`, `subscriptionType`, `rateLimitTier`, and any
  `mcpOAuth` block) using a write-to-temp + rename, the same way
  `codex_oauth_usage_reader.dart` handles `auth.json`.
* `invalid_grant` -> `notSignedIn`; other 4xx -> exponential back-off, keep the
  cached snapshot.
* Gate on `scopes.contains('user:profile')`; otherwise surface "run
  `claude setup-token`" copy instead of a generic "unavailable".
* Honour `CLAUDE_SECURESTORAGE_CONFIG_DIR` in `_readCredentialsFile()`.

**Step 4 — polish.**

* Show *why* Claude is disconnected in the card subtitle: "Claude Code not
  installed", "Signed out — run `claude`", "Browser session expired",
  "claude.ai blocked by Cloudflare (VPN?)".
* Add a diagnostics line in Settings ("Claude source: OAuth file / claude.ai
  session / none") so bug reports are self-describing.

---

## 2. Why the popup does not open

### 2.1 Current click path

```
overlay HWND (WS_EX_LAYERED|TOOLWINDOW|TOPMOST|NOACTIVATE)
  WM_LBUTTONUP -> channel_->InvokeMethod("toggle")           [C++]
    -> WindowsTaskbarStatusService handler -> onToggle        [Dart]
      -> AppWindowService.togglePopover()
         -> windowManager.isVisible() ? hide() : showPopover()
            showPopover(): screenRetriever.getCursorScreenPoint()
                           windowManager.getSize()
                           screenRetriever.getAllDisplays()
                           windowManager.setPosition(); show(); focus()
```

Meanwhile, at startup the stock runner still does
`SetNextFrameCallback([&]{ this->Show(); })` in `flutter_window.cpp`, while
Dart calls `windowManager.hide()` inside `waitUntilReadyToShow`. Which one wins
is a race per launch.

Nothing in this path changed between v0.5.3 and v0.7.0, so either it never
worked on this particular PC (Windows builds come from CI; the fixes in 0.5.x
could not have been verified on this machine) or something environmental
differs (DPI/multi-monitor, Windows 11 24H2 taskbar).

### 2.2 Ranked hypotheses (each can be checked in one minute)

1. **Startup race leaves the host window "visible but empty/off-screen",
   so every click toggles it the wrong way.** If the runner's
   `this->Show()` fires after Dart's `hide()`, `IsWindowVisible()` is `true`
   and the first click *hides* it; if the window is a transparent, frameless
   380x520 surface sitting at (10,10) behind other windows, the user sees
   nothing either way.
   Check: right-click the overlay -> **Open dashboard** (this uses `show`,
   which does not consult `isVisible`). If that opens the popup, this is it.
2. **Foreground/activation rejection.** The overlay is `WS_EX_NOACTIVATE`
   and answers `MA_NOACTIVATE`, so our process never becomes foreground. By
   the time Dart runs `ShowWindowAsync` + `SetForegroundWindow` (several ms
   later, asynchronously) Windows may treat it as a background process and
   refuse foreground; with `SWP_NOACTIVATE`/`HWND_TOPMOST` re-asserted by the
   overlay's 1-second `WM_TIMER`, the popup can end up shown but instantly
   blurred and hidden by `_scheduleWindowsBlurHide` (150 ms).
   Check: temporarily set `_windowsBlurGracePeriod` to 5 s; if the popup
   flashes, it is this.
3. **Exception inside `showPopover()` before `show()`.** `getAllDisplays()`
   / `display.visiblePosition` / `_displayContaining(...).first` can throw on
   some multi-monitor + DPI setups, and the exception is swallowed by the
   method-channel handler, so nothing is shown and nothing is logged.
   Check: run the exe from a terminal (`ai_limit_status.exe` from cmd, the
   runner attaches the console) and click — Dart exceptions print there.
4. Less likely: the click never reaches the overlay (Windows 11 taskbar XAML
   island above it). Check: does the *right*-click context menu appear? It uses
   the same `OverlayWindowProc`, so if the menu appears the click path is fine.

### 2.3 Fix plan for the popup (makes it robust regardless of which hypothesis is true)

**Step 1 — own visibility in one place, deterministically.**

* `windows/runner/flutter_window.cpp`: remove the `this->Show()` in
  `SetNextFrameCallback` (keep `ForceRedraw`). The window is created without
  `WS_VISIBLE`, and Dart already decides when it appears. This removes the
  race and makes `isVisible()` trustworthy.
* Keep `windowManager.hide()` in `waitUntilReadyToShow` as a belt-and-braces
  measure.

**Step 2 — show the popup natively, from inside the input handler.**

Move the "toggle" logic into `WindowsTaskbarStatus` so it runs synchronously
in `WM_LBUTTONUP`, while Windows still grants our process foreground rights:

```cpp
case WM_LBUTTONUP: {
  if (IsWindowVisible(host_window_)) {
    ShowWindow(host_window_, SW_HIDE);
    InvokeDart("hidden");
  } else {
    RECT overlay{}; GetWindowRect(window, &overlay);
    HMONITOR monitor = MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST);
    MONITORINFO info{sizeof(info)}; GetMonitorInfoW(monitor, &info);   // rcWork excludes the taskbar
    RECT host{}; GetWindowRect(host_window_, &host);
    const int w = host.right - host.left, h = host.bottom - host.top;  // already DPI-scaled physical px
    int x = (overlay.left + overlay.right) / 2 - w / 2;
    int y = overlay.top - h - ScaleForDpi(8, dpi);                     // above a bottom taskbar
    // clamp x/y into info.rcWork; flip below for a top taskbar, beside for a vertical one
    SetWindowPos(host_window_, HWND_TOPMOST, x, y, 0, 0, SWP_NOSIZE | SWP_SHOWWINDOW);
    SetForegroundWindow(host_window_);
    InvokeDart("shown");
  }
  return 0;
}
```

* Everything is in physical pixels from Win32, so the DPI round-trip through
  `screen_retriever` -> Dart -> `window_manager` disappears, along with the
  three plugin calls that can throw.
* `AppWindowService` keeps `showPopover()` for macOS/Linux and for the
  context-menu "Open dashboard"; on Windows it becomes a thin wrapper that
  invokes a new `"showPopover"` method on the channel so both entry points use
  the native routine.
* Because `SetForegroundWindow` is called from the thread that just received
  the click, it is allowed even though the overlay is `NOACTIVATE`.

**Step 3 — keep the popup from being hidden by ourselves.**

* In `PositionOverlay()` (called every second by `WM_TIMER`), skip
  `SetWindowPos`/`ShowWindow` when nothing changed (compare the computed rect
  with the last applied one). Re-asserting `HWND_TOPMOST` each second is also
  what makes the overlay jump above the popup if they ever overlap.
* In `AppWindowService.onWindowBlur` (Windows): treat a blur that occurs
  within ~400 ms of a native "shown" callback as spurious (extend
  `_isShowing` from the native event instead of the Dart-side 250 ms delay).

**Step 4 — add a log so the next report is diagnosable.**

* Tiny `AppLog` (Dart) writing to
  `%LOCALAPPDATA%\AI Limit Status\logs\app.log` (rotate at 1 MB), enabled by a
  Settings toggle or `--debug-log`. Log: toggle received, `isVisible` result,
  chosen position, exceptions from `showPopover`, each Claude/Codex source
  attempt and its outcome (never tokens/cookies).
* Mirror the key native events (`WM_LBUTTONUP`, `SetForegroundWindow` result,
  `GetLastError`) with `OutputDebugStringW` so they are visible in DebugView.

**Step 5 — verify on a real Windows machine before release.**

* Manual checklist: 100 % and 150 % DPI; bottom, top and left taskbar; two
  monitors with different DPI; click, click again (hide), right-click menu,
  outside click dismiss, notification-area click keeps it open.
* Add a `flutter test` for `UsageRepositoryImpl` (providers are no longer
  dropped) and for `ClaudeUsageReader` issue precedence, using a fake
  `HttpClient`/file system so CI covers the Windows branches even though CI
  cannot click a taskbar.

---

## 3. Suggested order of work

1. Popup Steps 1–2 (runner + `WindowsTaskbarStatus`), and log (Step 4) —
   one PR, because the popup is what lets the user see the Claude card at all.
2. Claude Step 1 (stop hiding, actionable issue, `—` segment) — small PR.
3. Claude Step 3 (token refresh + write-back) — medium PR, mirrors Codex code.
4. Claude Step 2 (WebView2 "Connect claude.ai" + bridge status/one-click
   folder + advanced paste) — larger PR, needs the privacy statement updated.
5. Release as 0.8.0 with the Windows checklist from §2.3 Step 5 actually run
   on the Windows PC; note in the README that the extension bridge is optional
   and that "Connect claude.ai" is the recommended path.

---

## 4. Quick checks you can do on the Windows PC right now

1. Right-click the overlay -> Open dashboard. Does the popup open?
2. Does `%USERPROFILE%\.claude\.credentials.json` exist? (`claude` installed
   and signed in?) If yes, Claude should already work through OAuth — then the
   bug is elsewhere and the log from §2.3 Step 4 is needed.
3. `chrome://extensions` — is "AI Limit Status Browser Bridge" loaded and
   enabled? If not, the current build has no Claude source on this PC by
   design; that is exactly what Step 2 changes.
4. Run `ai_limit_status.exe` from a terminal and click the overlay: any Dart
   exception text?

## References

* CodexBar (macOS, Swift): https://github.com/steipete/codexbar —
  `Sources/CodexBarCore/Providers/Claude/*`, `docs/claude.md`
* Win-CodexBar (Rust/egui, DPAPI cookie extraction, manual cookie input):
  https://github.com/FrankOdey/Win-CodexBar
* CodexBar-Win (Python/customtkinter, CLI PTY -> OAuth file -> browser cookies):
  https://github.com/babakarto/CodexBar-Win
* window_manager 0.5.2 Windows implementation (`Show()` uses
  `ShowWindowAsync`; `WM_NCACTIVATE` drives focus/blur; `WM_NCHITTEST` returns
  `HTNOWHERE` when not resizable): https://pub.dev/packages/window_manager
* flutter_inappwebview CookieManager (Windows/WebView2 listed as supported):
  https://pub.dev/documentation/flutter_inappwebview/latest/flutter_inappwebview/CookieManager-class.html
