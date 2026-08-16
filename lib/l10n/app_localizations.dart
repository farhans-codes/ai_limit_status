import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Limit Status'**
  String get appTitle;

  /// No description provided for @providerCodex.
  ///
  /// In en, this message translates to:
  /// **'Codex'**
  String get providerCodex;

  /// No description provided for @providerClaude.
  ///
  /// In en, this message translates to:
  /// **'Claude'**
  String get providerClaude;

  /// No description provided for @remainingCompact.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String remainingCompact(int percent);

  /// No description provided for @remainingLabel.
  ///
  /// In en, this message translates to:
  /// **'{percent}% remaining'**
  String remainingLabel(int percent);

  /// No description provided for @fiveHourLimit.
  ///
  /// In en, this message translates to:
  /// **'5-hour limit'**
  String get fiveHourLimit;

  /// No description provided for @weeklyLimit.
  ///
  /// In en, this message translates to:
  /// **'Weekly limit'**
  String get weeklyLimit;

  /// No description provided for @opusWeeklyLimit.
  ///
  /// In en, this message translates to:
  /// **'Opus weekly limit'**
  String get opusWeeklyLimit;

  /// No description provided for @sonnetWeeklyLimit.
  ///
  /// In en, this message translates to:
  /// **'Sonnet weekly limit'**
  String get sonnetWeeklyLimit;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @cachedData.
  ///
  /// In en, this message translates to:
  /// **'Cached'**
  String get cachedData;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @resetsInHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'Resets in {hours}h {minutes}m'**
  String resetsInHoursMinutes(int hours, int minutes);

  /// No description provided for @resetsInDaysHours.
  ///
  /// In en, this message translates to:
  /// **'Resets in {days}d {hours}h'**
  String resetsInDaysHours(int days, int hours);

  /// No description provided for @resettingSoon.
  ///
  /// In en, this message translates to:
  /// **'Resetting soon'**
  String get resettingSoon;

  /// No description provided for @resetTimeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Reset time unavailable'**
  String get resetTimeUnavailable;

  /// No description provided for @lastUpdatedNow.
  ///
  /// In en, this message translates to:
  /// **'Updated just now'**
  String get lastUpdatedNow;

  /// No description provided for @lastUpdatedMinutes.
  ///
  /// In en, this message translates to:
  /// **'Updated {minutes}m ago'**
  String lastUpdatedMinutes(int minutes);

  /// No description provided for @autoRefreshMinutes.
  ///
  /// In en, this message translates to:
  /// **'Auto-refresh: {minutes} min'**
  String autoRefreshMinutes(int minutes);

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @loadingUsage.
  ///
  /// In en, this message translates to:
  /// **'Loading usage…'**
  String get loadingUsage;

  /// No description provided for @unableToLoadUsage.
  ///
  /// In en, this message translates to:
  /// **'Could not load usage information.'**
  String get unableToLoadUsage;

  /// No description provided for @noProvidersDetected.
  ///
  /// In en, this message translates to:
  /// **'No providers detected'**
  String get noProvidersDetected;

  /// No description provided for @noProvidersDetectedDescription.
  ///
  /// In en, this message translates to:
  /// **'Install Codex or Claude to start monitoring usage.'**
  String get noProvidersDetectedDescription;

  /// No description provided for @setUpProvider.
  ///
  /// In en, this message translates to:
  /// **'Set up {provider}'**
  String setUpProvider(String provider);

  /// No description provided for @liveData.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get liveData;

  /// No description provided for @notAvailableCompact.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get notAvailableCompact;

  /// No description provided for @cliNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'Install the provider CLI to read live subscription usage.'**
  String get cliNotFoundMessage;

  /// No description provided for @notSignedInMessage.
  ///
  /// In en, this message translates to:
  /// **'Sign in to the provider CLI to read live subscription usage.'**
  String get notSignedInMessage;

  /// No description provided for @providerUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Live usage is temporarily unavailable.'**
  String get providerUnavailableMessage;

  /// No description provided for @installAndSignIn.
  ///
  /// In en, this message translates to:
  /// **'Install & sign in'**
  String get installAndSignIn;

  /// No description provided for @openSetupGuide.
  ///
  /// In en, this message translates to:
  /// **'Open setup guide'**
  String get openSetupGuide;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @checkAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get checkAgain;

  /// No description provided for @signInStartedTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete sign-in'**
  String get signInStartedTitle;

  /// No description provided for @signInStartedMessage.
  ///
  /// In en, this message translates to:
  /// **'Finish {provider} sign-in in the terminal. This app will reconnect automatically.'**
  String signInStartedMessage(String provider);

  /// No description provided for @setupFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Setup could not finish'**
  String get setupFailedTitle;

  /// No description provided for @wingetUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Windows App Installer (WinGet) was not found. Open the setup guide to install the provider safely.'**
  String get wingetUnavailable;

  /// No description provided for @automaticSetupUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Automatic installation is not available on this platform. Open the official setup guide instead.'**
  String get automaticSetupUnavailable;

  /// No description provided for @providerSetupFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not set up {provider}. Open its official setup guide and try again.'**
  String providerSetupFailed(String provider);

  /// No description provided for @warningThresholdsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Usage alerts at 50%, 20%, and 10%; five-hour reminders at 1h, 30m, and 10m; weekly reminders at 1d, 12h, 5h, and 1h; plus restored notices'**
  String get warningThresholdsTooltip;

  /// No description provided for @settingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Notification and startup settings'**
  String get settingsTooltip;

  /// No description provided for @firstRunSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish app setup'**
  String get firstRunSetupTitle;

  /// No description provided for @firstRunSetupDescription.
  ///
  /// In en, this message translates to:
  /// **'Allow alerts and choose whether the app opens automatically when you sign in.'**
  String get firstRunSetupDescription;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'App settings'**
  String get settingsTitle;

  /// No description provided for @settingsDescription.
  ///
  /// In en, this message translates to:
  /// **'You can change notification and startup preferences at any time.'**
  String get settingsDescription;

  /// No description provided for @notificationAlertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Usage notifications'**
  String get notificationAlertsTitle;

  /// No description provided for @notificationAlertsDescription.
  ///
  /// In en, this message translates to:
  /// **'Usage alerts at 50%, 20%, and 10%; five-hour reminders at 1h, 30m, and 10m; weekly reminders at 1d, 12h, 5h, and 1h; plus restored notices.'**
  String get notificationAlertsDescription;

  /// No description provided for @launchAtStartupTitle.
  ///
  /// In en, this message translates to:
  /// **'Launch at startup'**
  String get launchAtStartupTitle;

  /// No description provided for @launchAtStartupDescription.
  ///
  /// In en, this message translates to:
  /// **'Open AI Limit Status automatically when you sign in.'**
  String get launchAtStartupDescription;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @settingsUpdateFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Setting not changed'**
  String get settingsUpdateFailedTitle;

  /// No description provided for @settingsUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'The setting could not be changed. Please try again.'**
  String get settingsUpdateFailed;

  /// No description provided for @notificationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Notification permission is off. Allow AI Limit Status in system notification settings.'**
  String get notificationPermissionDenied;

  /// No description provided for @startupApprovalRequired.
  ///
  /// In en, this message translates to:
  /// **'Approve AI Limit Status in the system Login Items or Startup Apps settings.'**
  String get startupApprovalRequired;

  /// No description provided for @startupUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Automatic startup is not supported on this operating system version.'**
  String get startupUnsupported;

  /// No description provided for @openSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSystemSettings;

  /// No description provided for @usageWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'{provider} usage warning'**
  String usageWarningTitle(String provider);

  /// No description provided for @resetWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'{provider} reset reminder'**
  String resetWarningTitle(String provider);

  /// No description provided for @remainingFiftyWarningBody.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of your {limit} remains. Use it carefully.'**
  String remainingFiftyWarningBody(String limit, int percent);

  /// No description provided for @remainingTwentyWarningBody.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Only {percent}% of your {limit} remains. Be extra cautious.'**
  String remainingTwentyWarningBody(String limit, int percent);

  /// No description provided for @remainingTenWarningBody.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Only {percent}% of your {limit} remains. Reduce your usage.'**
  String remainingTenWarningBody(String limit, int percent);

  /// No description provided for @resetOneDayWarningBody.
  ///
  /// In en, this message translates to:
  /// **'One day left until your {limit} resets.'**
  String resetOneDayWarningBody(String limit);

  /// No description provided for @resetTwelveHoursWarningBody.
  ///
  /// In en, this message translates to:
  /// **'12 hours left until your {limit} resets.'**
  String resetTwelveHoursWarningBody(String limit);

  /// No description provided for @resetFiveHoursWarningBody.
  ///
  /// In en, this message translates to:
  /// **'5 hours left until your {limit} resets.'**
  String resetFiveHoursWarningBody(String limit);

  /// No description provided for @resetOneHourWarningBody.
  ///
  /// In en, this message translates to:
  /// **'One hour left until your {limit} resets.'**
  String resetOneHourWarningBody(String limit);

  /// No description provided for @resetThirtyMinutesWarningBody.
  ///
  /// In en, this message translates to:
  /// **'30 minutes left until your {limit} resets.'**
  String resetThirtyMinutesWarningBody(String limit);

  /// No description provided for @resetTenMinutesWarningBody.
  ///
  /// In en, this message translates to:
  /// **'10 minutes left until your {limit} resets.'**
  String resetTenMinutesWarningBody(String limit);

  /// No description provided for @limitRestoredTitle.
  ///
  /// In en, this message translates to:
  /// **'{provider} limit restored'**
  String limitRestoredTitle(String provider);

  /// No description provided for @limitRestoredBody.
  ///
  /// In en, this message translates to:
  /// **'{limit} restored.'**
  String limitRestoredBody(String limit);

  /// No description provided for @openDashboard.
  ///
  /// In en, this message translates to:
  /// **'Open details'**
  String get openDashboard;

  /// No description provided for @quit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get quit;

  /// No description provided for @trayTitle.
  ///
  /// In en, this message translates to:
  /// **'{codexValue} · {claudeValue}'**
  String trayTitle(String codexValue, String claudeValue);

  /// No description provided for @trayTooltip.
  ///
  /// In en, this message translates to:
  /// **'Codex: {codexValue} · Claude 5-hour: {claudeValue}'**
  String trayTooltip(String codexValue, String claudeValue);

  /// No description provided for @singleProviderTrayTooltip.
  ///
  /// In en, this message translates to:
  /// **'{provider}: {value}'**
  String singleProviderTrayTooltip(String provider, String value);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
