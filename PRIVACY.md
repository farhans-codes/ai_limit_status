# Privacy

AI Limit Status is a local desktop application. It does not include analytics,
advertising, crash reporting, or maintainer-operated telemetry.

## Data the app reads

### Codex

The app reads the OAuth credential already created by Codex from the
provider-owned `auth.json` file under `CODEX_HOME` or the user's `.codex`
directory. It uses that credential to request usage from
`https://chatgpt.com/backend-api/wham/usage`.

Shortly before a token expires, the app may refresh it through
`https://auth.openai.com/oauth/token` and atomically write the rotated
credential back to the same provider-owned `auth.json` file so Codex and AI
Limit Status remain in sync. If the direct request is unavailable because the
credential is missing or rejected, the app can fall back to the locally
installed `codex app-server` process. Codex tokens are not written to AI Limit
Status cache or settings files and are not intentionally logged.

On macOS, if both Codex OAuth and the local app-server are unavailable, the app
can read the existing `chatgpt.com` session cookies from supported Safari,
Chromium, or Firefox browser profiles. macOS may request Keychain or Full Disk
Access permission for this read. The cookies are held in process memory, sent
only to `https://chatgpt.com/backend-api/wham/usage`, and are not written to AI
Limit Status cache, settings, or logs.

On Windows, users can optionally install the bundled browser extension. The
extension is allowlisted only for `chatgpt.com` and `claude.ai`, sends its
in-memory session snapshot to the local AI Limit Status process through browser
Native Messaging, and does not use extension storage. The app receives that
snapshot through a named pipe restricted to the signed-in Windows user.

### Claude

The app uses the OAuth credential already created by Claude Code:

- macOS: the `Claude Code-credentials` Keychain entry.
- Windows: the provider-owned `.claude/.credentials.json` file, or the path
  configured by `CLAUDE_CONFIG_DIR`.

The access token is kept in process memory while the app requests usage data
from `https://api.anthropic.com/api/oauth/usage`. The token is not written to AI
Limit Status cache or settings files and is not intentionally logged.

When the credential comes from the `.credentials.json` file and is about to
expire, the app may refresh it through `https://platform.claude.com/v1/oauth/token`
using Claude Code's own OAuth client and atomically write the rotated credential
back to the same provider-owned file so Claude Code and AI Limit Status remain
in sync. Keychain-held credentials are never refreshed or rewritten by the app.

On macOS, if the OAuth usage endpoint is unavailable, the app can read the
existing `claude.ai` `sessionKey` cookie from supported Safari, Chromium, or
Firefox browser profiles. macOS may request Keychain or Full Disk Access
permission for this read. The session key is held in process memory, sent only
to `https://claude.ai/api`, and is not written to AI Limit Status cache,
settings, or logs.

On Windows, the same provider request can use the in-memory session supplied by
the optional browser extension described above. Neither browser session is
written to AI Limit Status cache, settings, diagnostic logs, or analytics.

## Data stored locally

AI Limit Status can store:

- Remaining usage percentages.
- Reset timestamps.
- The time of the last successful refresh.
- Notification, startup, and provider-visibility preferences.
- Identifiers used to avoid duplicate notifications.
- A small local diagnostic log (`logs/app.log`, capped at 512 KB plus one
  rotated copy) recording window and provider events such as "popover shown"
  or "OAuth usage read failed: notSignedIn". It never contains tokens,
  cookies, or usage payloads and is never uploaded.

On macOS these files are kept under
`~/Library/Application Support/AI Limit Status` (the diagnostic log under
`~/Library/Logs/AI Limit Status`). On Windows they are kept under the user's
local application-data directory (`%LOCALAPPDATA%\AI Limit Status`).

## Network requests

The app does not send data to the project maintainer. Network activity is
limited to provider-owned services required to retrieve usage, refresh Codex
or Claude credentials when necessary, and open official setup links selected by
the user.

## Removing local data

Quit AI Limit Status, uninstall the application, and remove its application-data
directory to delete locally cached usage and preferences. Removing AI Limit
Status does not remove Codex or Claude credentials owned by their respective
CLIs.

## Changes

Privacy-impacting changes must be documented in the release notes and this
file. Users should review those documents before installing an update.
