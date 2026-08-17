# Changelog

All notable changes to AI Limit Status are documented here.

The project follows Semantic Versioning for public releases.

## [Unreleased]

## [0.3.1] - 2026-08-17

### Added

- Direct macOS and Windows download links in the project README.

### Changed

- Adopted version-independent filenames for release downloads and the Windows
  installer.
- Extended CI coverage and the documented contribution flow to the protected
  `develop` branch.
- Updated pinned GitHub Actions used to build and publish releases.

## [0.3.0] - 2026-08-16

### Added

- Dynamic provider visibility based on locally installed CLIs.
- Notification permission and launch-at-startup settings.
- Restored notifications for Claude five-hour and provider weekly limits.
- Five-hour reset reminders at one hour, 30 minutes, and 10 minutes.
- Weekly reset reminders at one day, 12 hours, five hours, and one hour.
- Remaining-usage warnings at 50%, 20%, and 10%.

### Changed

- Reworked notification copy to distinguish restored limits from countdown
  reminders.
- Improved Claude connection reliability and cached usage behavior.

## [0.2.2] - 2026-08-13

### Added

- macOS menu-bar and Windows system-tray status.
- Guided Codex and Claude setup.
- Local usage caching and duplicate-instance protection.

[Unreleased]: https://github.com/farhans-codes/ai_limit_status/compare/v0.3.1...HEAD
[0.3.1]: https://github.com/farhans-codes/ai_limit_status/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/farhans-codes/ai_limit_status/releases/tag/v0.3.0
[0.2.2]: https://github.com/farhans-codes/ai_limit_status/releases/tag/v0.2.2
