class AppStrings {
  const AppStrings._();

  static const instance = AppStrings._();

  String get appTitle => 'AI Limit Status';
  String get providerCodex => 'Codex';
  String get providerClaude => 'Claude';

  String remainingCompact(int percent) => '$percent%';
  String remainingLabel(int percent) => '$percent% remaining';

  String get fiveHourLimit => '5-hour limit';
  String get weeklyLimit => 'Weekly limit';
  String get fableWeeklyLimit => 'Fable weekly limit';
  String get opusWeeklyLimit => 'Opus weekly limit';
  String get sonnetWeeklyLimit => 'Sonnet weekly limit';
  String get connected => 'Connected';
  String get cachedData => 'Cached';
  String get disconnected => 'Disconnected';

  String resetsInHoursMinutes(int hours, int minutes) =>
      'Resets in ${hours}h ${minutes}m';

  String resetsInDaysHours(int days, int hours) =>
      'Resets in ${days}d ${hours}h';

  String get resettingSoon => 'Resetting soon';
  String get resetTimeUnavailable => 'Reset time unavailable';
  String get lastUpdatedNow => 'Updated just now';
  String lastUpdatedMinutes(int minutes) => 'Updated ${minutes}m ago';
  String get refresh => 'Refresh';
  String get retry => 'Retry';
  String get loadingUsage => 'Loading usage…';
  String get unableToLoadUsage => 'Could not load usage information.';
  String get noProvidersDetected => 'No providers detected';
  String get noProvidersDetectedDescription =>
      'Install Codex or Claude to start monitoring usage.';
  String setUpProvider(String provider) => 'Set up $provider';
  String get notAvailableCompact => '—';
  String get cliNotFoundMessage =>
      'Install the provider CLI to read live subscription usage.';
  String get notSignedInMessage =>
      'Sign in to the provider CLI to read live subscription usage.';
  String get providerUnavailableMessage =>
      'Live usage is temporarily unavailable.';
  String get browserSessionExpiredMessage =>
      'Your claude.ai browser session was rejected. Sign in to claude.ai '
      'again, or sign in to the Claude CLI.';
  String get browserBlockedMessage =>
      'claude.ai answered with a Cloudflare challenge (common on VPN or '
      'datacenter networks). Signing in again will not help; try another '
      'network or install Claude Code.';

  String get installAndSignIn => 'Install & sign in';
  String get openSetupGuide => 'Open setup guide';
  String get signIn => 'Sign in';
  String get checkAgain => 'Check again';
  String get signInStartedTitle => 'Complete sign-in';

  String signInStartedMessage(String provider) =>
      'Finish $provider sign-in in the terminal. '
      'This app will reconnect automatically.';

  String get setupFailedTitle => 'Setup could not finish';
  String get wingetUnavailable =>
      'Windows App Installer (WinGet) was not found. '
      'Open the setup guide to install the provider safely.';
  String get automaticSetupUnavailable =>
      'Automatic installation is not available on this platform. '
      'Open the official setup guide instead.';

  String providerSetupFailed(String provider) =>
      'Could not set up $provider. '
      'Open its official setup guide and try again.';

  String get warningThresholdsTooltip =>
      'Usage alerts at 50%, 20%, and 10%; five-hour reminders at 1h, '
      '30m, and 10m; weekly reminders at 1d, 12h, 5h, and 1h; '
      'plus restored notices';
  String get settingsTooltip => 'Notification, shortcut, and startup settings';
  String get firstRunSetupTitle => 'Finish app setup';
  String get firstRunSetupDescription =>
      'Choose how AI Limit Status should work for you.';
  String get settingsTitle => 'Settings';
  String get settingsDescription =>
      'Control alerts, startup, and what appears in your status shortcut.';
  String get generalSettingsSectionTitle => 'General';
  String get notificationAlertsTitle => 'Usage notifications';
  String get notificationAlertsDescription =>
      'Alerts at 50%, 20%, and 10%, plus reset reminders.';
  String get launchAtStartupTitle => 'Launch at startup';
  String get launchAtStartupDescription =>
      'Start automatically when you sign in.';
  String get statusShortcutSectionTitle => 'Status shortcut';
  String get claudeShortcutLimitTitle => 'Claude limit';
  String get claudeShortcutLimitDescription =>
      'Choose the percentage shown in the menu bar or Windows taskbar.';
  String get claudeFiveHourShortcut => '5-hour';
  String get claudeFableShortcut => 'Fable weekly';
  String get providersSectionTitle => 'Visible providers';
  String get showCodexTitle => 'Codex';
  String get showClaudeTitle => 'Claude';
  String get providerVisibilityDescription =>
      'Only enabled providers are read and shown.';
  String get close => 'Close';
  String get finishSetup => 'Finish setup';
  String get done => 'Done';
  String get settingsUpdateFailedTitle => 'Setting not changed';
  String get settingsUpdateFailed =>
      'The setting could not be changed. Please try again.';
  String get notificationPermissionDenied =>
      'Notification permission is off. Allow AI Limit Status in '
      'system notification settings.';
  String get startupApprovalRequired =>
      'Approve AI Limit Status in the system Login Items or Startup Apps '
      'settings.';
  String get startupUnsupported =>
      'Automatic startup is not supported on this operating system version.';
  String get openSystemSettings => 'Open settings';

  String usageWarningTitle(String provider) => '$provider usage warning';
  String resetWarningTitle(String provider) => '$provider reset reminder';

  String remainingFiftyWarningBody(String limit, int percent) =>
      '$percent% of your $limit remains. Use it carefully.';

  String remainingTwentyWarningBody(String limit, int percent) =>
      'Only $percent% of your $limit remains. Be extra cautious.';

  String remainingTenWarningBody(String limit, int percent) =>
      'Only $percent% of your $limit remains. Reduce your usage.';

  String resetOneDayWarningBody(String limit) =>
      'One day left until your $limit resets.';

  String resetTwelveHoursWarningBody(String limit) =>
      '12 hours left until your $limit resets.';

  String resetFiveHoursWarningBody(String limit) =>
      '5 hours left until your $limit resets.';

  String resetOneHourWarningBody(String limit) =>
      'One hour left until your $limit resets.';

  String resetThirtyMinutesWarningBody(String limit) =>
      '30 minutes left until your $limit resets.';

  String resetTenMinutesWarningBody(String limit) =>
      '10 minutes left until your $limit resets.';

  String limitRestoredTitle(String provider) => '$provider limit restored';
  String limitRestoredBody(String limit) => '$limit restored.';
  String get openDashboard => 'Open details';
  String get quit => 'Quit';

  String trayTitle(String codexValue, String claudeValue) =>
      '$codexValue · $claudeValue';

  String trayTooltip(
    String codexValue,
    String claudeLimit,
    String claudeValue,
  ) => 'Codex: $codexValue · Claude $claudeLimit: $claudeValue';

  String singleClaudeTrayTooltip(String claudeLimit, String value) =>
      'Claude $claudeLimit: $value';

  String singleProviderTrayTooltip(String provider, String value) =>
      '$provider: $value';
}
