class DesktopSettings {
  const DesktopSettings({
    required this.notificationsEnabled,
    required this.launchAtStartupEnabled,
    required this.onboardingCompleted,
  });

  final bool notificationsEnabled;
  final bool launchAtStartupEnabled;
  final bool onboardingCompleted;
}

enum DesktopSettingUpdateResult {
  succeeded,
  permissionDenied,
  requiresApproval,
  unsupported,
  failed,
}
