// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AI Limit Status';

  @override
  String get providerCodex => 'Codex';

  @override
  String get providerClaude => 'Claude';

  @override
  String remainingCompact(int percent) {
    return '$percent%';
  }

  @override
  String remainingLabel(int percent) {
    return '$percent% remaining';
  }

  @override
  String get fiveHourLimit => '5-hour limit';

  @override
  String get weeklyLimit => 'Weekly limit';

  @override
  String get opusWeeklyLimit => 'Opus weekly limit';

  @override
  String get sonnetWeeklyLimit => 'Sonnet weekly limit';

  @override
  String get connected => 'Connected';

  @override
  String get cachedData => 'Cached';

  @override
  String get disconnected => 'Disconnected';

  @override
  String resetsInHoursMinutes(int hours, int minutes) {
    return 'Resets in ${hours}h ${minutes}m';
  }

  @override
  String resetsInDaysHours(int days, int hours) {
    return 'Resets in ${days}d ${hours}h';
  }

  @override
  String get resettingSoon => 'Resetting soon';

  @override
  String get resetTimeUnavailable => 'Reset time unavailable';

  @override
  String get lastUpdatedNow => 'Updated just now';

  @override
  String lastUpdatedMinutes(int minutes) {
    return 'Updated ${minutes}m ago';
  }

  @override
  String autoRefreshMinutes(int minutes) {
    return 'Auto-refresh: $minutes min';
  }

  @override
  String get refresh => 'Refresh';

  @override
  String get retry => 'Retry';

  @override
  String get loadingUsage => 'Loading usage…';

  @override
  String get unableToLoadUsage => 'Could not load usage information.';

  @override
  String get noProvidersDetected => 'No providers detected';

  @override
  String get noProvidersDetectedDescription =>
      'Install Codex or Claude to start monitoring usage.';

  @override
  String setUpProvider(String provider) {
    return 'Set up $provider';
  }

  @override
  String get liveData => 'Live';

  @override
  String get notAvailableCompact => '—';

  @override
  String get cliNotFoundMessage =>
      'Install the provider CLI to read live subscription usage.';

  @override
  String get notSignedInMessage =>
      'Sign in to the provider CLI to read live subscription usage.';

  @override
  String get providerUnavailableMessage =>
      'Live usage is temporarily unavailable.';

  @override
  String get installAndSignIn => 'Install & sign in';

  @override
  String get openSetupGuide => 'Open setup guide';

  @override
  String get signIn => 'Sign in';

  @override
  String get checkAgain => 'Check again';

  @override
  String get signInStartedTitle => 'Complete sign-in';

  @override
  String signInStartedMessage(String provider) {
    return 'Finish $provider sign-in in the terminal. This app will reconnect automatically.';
  }

  @override
  String get setupFailedTitle => 'Setup could not finish';

  @override
  String get wingetUnavailable =>
      'Windows App Installer (WinGet) was not found. Open the setup guide to install the provider safely.';

  @override
  String get automaticSetupUnavailable =>
      'Automatic installation is not available on this platform. Open the official setup guide instead.';

  @override
  String providerSetupFailed(String provider) {
    return 'Could not set up $provider. Open its official setup guide and try again.';
  }

  @override
  String get warningThresholdsTooltip =>
      'Usage alerts at 50%, 20%, and 10%; five-hour reminders at 1h, 30m, and 10m; weekly reminders at 1d, 12h, 5h, and 1h; plus restored notices';

  @override
  String get settingsTooltip => 'Notification and startup settings';

  @override
  String get firstRunSetupTitle => 'Finish app setup';

  @override
  String get firstRunSetupDescription =>
      'Allow alerts and choose whether the app opens automatically when you sign in.';

  @override
  String get settingsTitle => 'App settings';

  @override
  String get settingsDescription =>
      'You can change notification and startup preferences at any time.';

  @override
  String get notificationAlertsTitle => 'Usage notifications';

  @override
  String get notificationAlertsDescription =>
      'Usage alerts at 50%, 20%, and 10%; five-hour reminders at 1h, 30m, and 10m; weekly reminders at 1d, 12h, 5h, and 1h; plus restored notices.';

  @override
  String get launchAtStartupTitle => 'Launch at startup';

  @override
  String get launchAtStartupDescription =>
      'Open AI Limit Status automatically when you sign in.';

  @override
  String get done => 'Done';

  @override
  String get settingsUpdateFailedTitle => 'Setting not changed';

  @override
  String get settingsUpdateFailed =>
      'The setting could not be changed. Please try again.';

  @override
  String get notificationPermissionDenied =>
      'Notification permission is off. Allow AI Limit Status in system notification settings.';

  @override
  String get startupApprovalRequired =>
      'Approve AI Limit Status in the system Login Items or Startup Apps settings.';

  @override
  String get startupUnsupported =>
      'Automatic startup is not supported on this operating system version.';

  @override
  String get openSystemSettings => 'Open settings';

  @override
  String usageWarningTitle(String provider) {
    return '$provider usage warning';
  }

  @override
  String resetWarningTitle(String provider) {
    return '$provider reset reminder';
  }

  @override
  String remainingFiftyWarningBody(String limit, int percent) {
    return '$percent% of your $limit remains. Use it carefully.';
  }

  @override
  String remainingTwentyWarningBody(String limit, int percent) {
    return '⚠️ Only $percent% of your $limit remains. Be extra cautious.';
  }

  @override
  String remainingTenWarningBody(String limit, int percent) {
    return '⚠️ Only $percent% of your $limit remains. Reduce your usage.';
  }

  @override
  String resetOneDayWarningBody(String limit) {
    return 'One day left until your $limit resets.';
  }

  @override
  String resetTwelveHoursWarningBody(String limit) {
    return '12 hours left until your $limit resets.';
  }

  @override
  String resetFiveHoursWarningBody(String limit) {
    return '5 hours left until your $limit resets.';
  }

  @override
  String resetOneHourWarningBody(String limit) {
    return 'One hour left until your $limit resets.';
  }

  @override
  String resetThirtyMinutesWarningBody(String limit) {
    return '30 minutes left until your $limit resets.';
  }

  @override
  String resetTenMinutesWarningBody(String limit) {
    return '10 minutes left until your $limit resets.';
  }

  @override
  String limitRestoredTitle(String provider) {
    return '$provider limit restored';
  }

  @override
  String limitRestoredBody(String limit) {
    return '$limit restored.';
  }

  @override
  String get openDashboard => 'Open details';

  @override
  String get quit => 'Quit';

  @override
  String trayTitle(String codexValue, String claudeValue) {
    return '$codexValue · $claudeValue';
  }

  @override
  String trayTooltip(String codexValue, String claudeValue) {
    return 'Codex: $codexValue · Claude 5-hour: $claudeValue';
  }

  @override
  String singleProviderTrayTooltip(String provider, String value) {
    return '$provider: $value';
  }
}
