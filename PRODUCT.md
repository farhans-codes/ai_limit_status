# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

Marketing site: plain static HTML/CSS with no build step, served by GitHub
Pages at `farhans-codes.github.io/ai_limit_status`. The product itself is a
Flutter desktop app (macOS and Windows) in this repository.

## Users

Developers on a paid Claude Code or Codex plan who code with these tools every
day on a Mac or a Windows PC, and who worry about hitting a usage limit in the
middle of work.

## Product Purpose

AI Limit Status keeps the remaining Claude and Codex subscription limits
visible at all times, so users can pace their work and are never surprised by
a limit. Success is a user who never has to open a browser or a terminal to
know how much they have left.

## Positioning

It runs on both macOS (menu bar) and Windows (taskbar) and shows Codex and
Claude side by side. Comparable tools, such as CodexBar, are macOS-only. This
is the lead difference to communicate.

## Operating Context

- Lives in the macOS menu bar or the Windows taskbar; a popover shows each
  provider's weekly limits, model-specific Claude limits, and reset times.
- Reuses the sign-in the Claude Code and Codex CLIs already created; no API
  key or account in the app.
- Desktop notifications at 50%, 20% and 10% remaining, plus reminders before a
  limit resets.
- Updates install in one click from Settings (from v1.0.0).
- Distribution: GitHub Releases (DMG, ZIP, Windows Setup EXE, portable ZIP)
  and Homebrew (`brew install --cask farhans-codes/tap/ai-limit-status`).

## Capabilities and Constraints

- Free and open source (MIT). No analytics or telemetry.
- macOS 13 or newer; Windows x64. The Windows taskbar display is experimental.
- The macOS app is not notarized by Apple; first launch may need Open Anyway.
- Not affiliated with, endorsed by, or sponsored by OpenAI or Anthropic. This
  disclaimer must appear on public surfaces.

## Brand Commitments

- Name: "AI Limit Status". App icon: `assets/branding/app_icon.png`.
- English-only copy.

## Evidence on Hand

- Real screenshots: `docs/screenshots/macos-menu-bar-and-popover.png`,
  `docs/screenshots/macos-usage-popover.png`.
- No testimonials, user counts, press, or ratings exist. Do not invent them.

## Product Principles

1. Glanceable first: the number matters more than the chrome around it.
2. Zero setup: work with what the user already signed in to.
3. Stay out of the way: quiet until a limit actually needs attention.
4. Honest about state: always say how fresh a number is.
