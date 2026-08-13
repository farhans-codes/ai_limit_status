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
  /// **'Alerts at 50% and 20% remaining, and 5h and 1h before reset'**
  String get warningThresholdsTooltip;

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

  /// No description provided for @remainingWarningBody.
  ///
  /// In en, this message translates to:
  /// **'{limit} has {percent}% remaining (the {threshold}% alert).'**
  String remainingWarningBody(String limit, int percent, int threshold);

  /// No description provided for @resetWarningBody.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1{{limit} will reset within 1 hour.} other{{limit} will reset within {hours} hours.}}'**
  String resetWarningBody(String limit, int hours);

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
