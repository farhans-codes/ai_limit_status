enum ClaudeStatusLimitPreference { fiveHour, fableWeekly }

class DesktopSettings {
  const DesktopSettings({
    required this.notificationsEnabled,
    required this.launchAtStartupEnabled,
    required this.onboardingCompleted,
    required this.claudeStatusLimitPreference,
  });

  final bool notificationsEnabled;
  final bool launchAtStartupEnabled;
  final bool onboardingCompleted;
  final ClaudeStatusLimitPreference claudeStatusLimitPreference;
}

enum DesktopSettingUpdateResult {
  succeeded,
  permissionDenied,
  requiresApproval,
  unsupported,
  failed,
}
