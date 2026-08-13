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
}
