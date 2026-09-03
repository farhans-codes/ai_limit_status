import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

enum ClaudeStatusLimitPreference { fiveHour, fableWeekly }

class DesktopSettings {
  const DesktopSettings({
    required this.notificationsEnabled,
    required this.launchAtStartupEnabled,
    required this.onboardingCompleted,
    required this.claudeStatusLimitPreference,
    required this.visibleProviders,
    required this.hasManualClaudeSessionKey,
  });

  final bool notificationsEnabled;
  final bool launchAtStartupEnabled;
  final bool onboardingCompleted;
  final ClaudeStatusLimitPreference claudeStatusLimitPreference;

  /// Providers the user wants in the details window and status shortcut.
  /// Disconnected providers stay visible (with setup actions) unless hidden
  /// here explicitly.
  final Set<UsageProvider> visibleProviders;

  /// Whether a claude.ai session key pasted by the user is stored locally.
  final bool hasManualClaudeSessionKey;
}

enum DesktopSettingUpdateResult {
  succeeded,
  permissionDenied,
  requiresApproval,
  unsupported,
  failed,
}
