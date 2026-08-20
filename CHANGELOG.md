# Changelog

All notable changes to AI Limit Status are documented here.

The project follows Semantic Versioning for public releases.

## [Unreleased]

## [0.5.3] - 2026-08-20

### Fixed

- Kept the Windows details window visible while users interact with the
  taskbar, notification area, and overflow controls, while preserving
  outside-click dismissal.
- Made the complete transparent Windows taskbar status surface clickable,
  including the space between each provider icon and percentage.
- Hid the internal macOS DMG background asset from the Finder installer canvas
  without removing the branded installer artwork.

## [0.5.2] - 2026-08-20

### Fixed

- Prevented the Windows details popup from briefly hiding and reopening when
  its taskbar status control is clicked.
- Replaced the placeholder Codex taskbar mark with the proper OpenAI glyph.

## [0.5.1] - 2026-08-20

### Fixed

- Removed the colored backgrounds from the Windows taskbar indicators so they
  appear directly on the transparent taskbar surface.
- Removed the retained native Windows frame that caused a second rounded border
  around the glass-style details window.

## [0.5.0] - 2026-08-18

### Added

- Added a Claude shortcut preference for choosing between the normal five-hour
  limit and the Fable weekly limit in the macOS menu bar or Windows taskbar.
- Added a bundled custom chime for usage warnings, reset reminders, and restored
  limit notifications on macOS and Windows.

### Changed

- Replaced the separate Windows notification-area badges with an experimental
  taskbar overlay that shows blue Codex and orange Claude indicators side by
  side and preserves the existing click and context-menu actions.
- Increased the macOS menu-bar provider icon and percentage sizes and aligned
  them vertically with neighboring status items.

## [0.4.1] - 2026-08-18

### Fixed

- Bundled the Visual C++ runtime DLLs required by Flutter in both the Windows
  installer and portable release, preventing startup failures on clean Windows
  installations.
- Clarified that the complete portable archive must be extracted before the
  application is opened so Windows can load every bundled dependency.

## [0.4.0] - 2026-08-18

### Added

- Added native Windows tray badges that show the live Codex and Claude
  remaining percentages directly in the notification area.
- Added dynamic Claude Fable weekly usage when Anthropic reports a scoped Fable
  limit through either the current or legacy usage response schema.

### Changed

- Replaced the single static Windows tray icon with separate provider-colored
  status badges while keeping the combined usage details in the hover tooltip.
- Unified Codex and Claude background usage refreshes on a two-minute cadence.
- Upgraded the details window with layered glass surfaces and removed redundant
  live-state and automatic-refresh labels.

## [0.3.3] - 2026-08-17

### Changed

- Upgraded and fully pinned the macOS DMG metadata toolchain.
- Made the DMG build script select a compatible Python 3.10+ interpreter and
  report an actionable error when one is unavailable.
- Simplified the DMG artwork so the installation controls and project privacy
  details fit within the visible Finder area.
- Removed redundant warning emoji from low-remaining usage notifications.

### Fixed

- Restored the branded Finder background in macOS Tahoe DMG windows.

## [0.3.2] - 2026-08-17

### Added

- Added a branded macOS DMG layout with installation guidance and concise
  project information.

### Changed

- Made macOS DMG creation deterministic in the release workflow using a pinned
  packaging dependency.
- Documented the custom DMG background limitation in macOS Tahoe while keeping
  drag-to-Applications installation fully supported.

## [0.3.1] - 2026-08-17

### Added

- Direct macOS and Windows download links in the project README.

### Changed

- Adopted version-independent filenames for release downloads and the Windows
  installer.
- Extended CI coverage and the documented contribution flow to the protected
  `develop` branch.
- Updated pinned GitHub Actions used to build and publish releases.

### Fixed

- Prevented small upstream reset-time changes from producing repeated false
  restored notifications for Claude five-hour and weekly limits.
- Limited remaining-usage and reset countdown alerts to actual threshold
  entries instead of reevaluating them on every refresh.

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

[Unreleased]: https://github.com/farhans-codes/ai_limit_status/compare/v0.5.3...HEAD
[0.5.3]: https://github.com/farhans-codes/ai_limit_status/compare/v0.5.2...v0.5.3
[0.5.2]: https://github.com/farhans-codes/ai_limit_status/compare/v0.5.1...v0.5.2
[0.5.1]: https://github.com/farhans-codes/ai_limit_status/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/farhans-codes/ai_limit_status/compare/v0.4.1...v0.5.0
[0.4.1]: https://github.com/farhans-codes/ai_limit_status/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/farhans-codes/ai_limit_status/compare/v0.3.3...v0.4.0
[0.3.3]: https://github.com/farhans-codes/ai_limit_status/compare/v0.3.2...v0.3.3
[0.3.2]: https://github.com/farhans-codes/ai_limit_status/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/farhans-codes/ai_limit_status/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/farhans-codes/ai_limit_status/releases/tag/v0.3.0
[0.2.2]: https://github.com/farhans-codes/ai_limit_status/releases/tag/v0.2.2
