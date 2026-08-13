# AI Limit Status

A lightweight macOS menu bar and Windows system tray app for monitoring Codex
and Claude subscription usage.

## Highlights

- Shows Codex and Claude remaining usage from the status bar or system tray.
- Displays 5-hour, weekly, Opus, and Sonnet windows when available.
- Sends one-time system notifications at 50% and 20% remaining.
- Sends reset reminders when 5 hours and 1 hour remain.
- Detects CLIs installed through WinGet, native installers, Homebrew, or npm.
- Offers guided Install, Sign in, and Check again actions inside the app.

## First-time setup

Install AI Limit Status and open it from the tray. Each provider is independent,
so users only need to connect the services they use.

On Windows, choose **Install & sign in** on a disconnected provider. The app uses
the official WinGet packages (`OpenAI.Codex` and `Anthropic.ClaudeCode`), opens
the provider's sign-in flow, then checks for the connection automatically.

On macOS, install the provider once from the official
[Codex CLI](https://developers.openai.com/codex/cli/) or
[Claude Code](https://code.claude.com/docs/en/getting-started) guide. AI Limit
Status detects common native, Homebrew, and local CLI paths; choose **Sign in**
or **Check again** from the provider card afterward.

No API key needs to be pasted into AI Limit Status. Authentication remains in
the provider's own CLI credential storage.

## Warning thresholds

Warnings are enabled by default at:

- 50% remaining
- 20% remaining
- 5 hours before a usage window resets
- 1 hour before a usage window resets

Each threshold is shown only once for a given reset window, even when the app
refreshes in the background every minute.
