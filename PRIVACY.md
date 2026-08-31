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

### Claude

The app uses the OAuth credential already created by Claude Code:

- macOS: the `Claude Code-credentials` Keychain entry.
- Windows: the provider-owned `.claude/.credentials.json` file, or the path
  configured by `CLAUDE_CONFIG_DIR`.

The access token is kept in process memory while the app requests usage data
from `https://api.anthropic.com/api/oauth/usage`. The token is not written to AI
Limit Status cache or settings files and is not intentionally logged.

## Data stored locally

AI Limit Status can store:

- Remaining usage percentages.
- Reset timestamps.
- The time of the last successful refresh.
- Notification and startup preferences.
- Identifiers used to avoid duplicate notifications.

On macOS these files are kept under
`~/Library/Application Support/AI Limit Status`. On Windows they are kept under
the user's local application-data directory.

## Network requests

The app does not send data to the project maintainer. Network activity is
limited to provider-owned services required to retrieve usage, refresh Codex
credentials when necessary, and open official setup links selected by the
user.

## Removing local data

Quit AI Limit Status, uninstall the application, and remove its application-data
directory to delete locally cached usage and preferences. Removing AI Limit
Status does not remove Codex or Claude credentials owned by their respective
CLIs.

## Changes

Privacy-impacting changes must be documented in the release notes and this
file. Users should review those documents before installing an update.
