import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

enum ClaudeStatusLimitPreference {
  weekly,
  fableWeekly;

  /// Source compatibility for callers using the retired shortcut preference.
  /// Persisted `fiveHour` values are also read as [weekly].
  static const fiveHour = weekly;
}

class DesktopSettings {
  /// The most providers the menu bar or taskbar status shows at once, so the
  /// app never crowds out the user's other status items.
  static const maxStatusBarProviders = 3;

  const DesktopSettings({
    required this.notificationsEnabled,
    required this.launchAtStartupEnabled,
    required this.onboardingCompleted,
    required this.claudeStatusLimitPreference,
    required this.visibleProviders,
    this.statusBarHiddenProviders = const {},
  });

  final bool notificationsEnabled;
  final bool launchAtStartupEnabled;
  final bool onboardingCompleted;
  final ClaudeStatusLimitPreference claudeStatusLimitPreference;

  /// Providers the user wants in the details window and status shortcut.
  /// Disconnected providers stay visible (with setup actions) unless hidden
  /// here explicitly.
  final Set<UsageProvider> visibleProviders;

  /// Visible providers the user keeps out of the menu bar or taskbar status.
  final Set<UsageProvider> statusBarHiddenProviders;
}

enum DesktopSettingUpdateResult {
  succeeded,
  permissionDenied,
  requiresApproval,
  unsupported,
  failed,
}
