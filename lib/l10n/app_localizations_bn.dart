// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

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
    return '$percent% বাকি';
  }

  @override
  String get fiveHourLimit => '৫ ঘণ্টার সীমা';

  @override
  String get weeklyLimit => 'সাপ্তাহিক সীমা';

  @override
  String get opusWeeklyLimit => 'Opus সাপ্তাহিক সীমা';

  @override
  String get sonnetWeeklyLimit => 'Sonnet সাপ্তাহিক সীমা';

  @override
  String get connected => 'সংযুক্ত';

  @override
  String get cachedData => 'সংরক্ষিত';

  @override
  String get disconnected => 'সংযোগ নেই';

  @override
  String resetsInHoursMinutes(int hours, int minutes) {
    return 'রিসেট হবে $hours ঘণ্টা $minutes মিনিট পরে';
  }

  @override
  String resetsInDaysHours(int days, int hours) {
    return 'রিসেট হবে $days দিন $hours ঘণ্টা পরে';
  }

  @override
  String get resettingSoon => 'শীঘ্রই রিসেট হবে';

  @override
  String get resetTimeUnavailable => 'রিসেটের সময় পাওয়া যায়নি';

  @override
  String get lastUpdatedNow => 'এইমাত্র আপডেট হয়েছে';

  @override
  String lastUpdatedMinutes(int minutes) {
    return '$minutes মিনিট আগে আপডেট হয়েছে';
  }

  @override
  String autoRefreshMinutes(int minutes) {
    return 'অটো-রিফ্রেশ: $minutes মিনিট';
  }

  @override
  String get refresh => 'রিফ্রেশ';

  @override
  String get retry => 'আবার চেষ্টা করুন';

  @override
  String get loadingUsage => 'ব্যবহারের তথ্য লোড হচ্ছে…';

  @override
  String get unableToLoadUsage => 'ব্যবহারের তথ্য লোড করা যায়নি।';

  @override
  String get noProvidersDetected => 'কোনো provider পাওয়া যায়নি';

  @override
  String get noProvidersDetectedDescription =>
      'ব্যবহার পর্যবেক্ষণ করতে Codex বা Claude ইনস্টল করুন।';

  @override
  String setUpProvider(String provider) {
    return '$provider সেটআপ করুন';
  }

  @override
  String get liveData => 'লাইভ';

  @override
  String get notAvailableCompact => '—';

  @override
  String get cliNotFoundMessage =>
      'লাইভ সাবস্ক্রিপশন ব্যবহার দেখতে provider CLI ইনস্টল করুন।';

  @override
  String get notSignedInMessage =>
      'লাইভ সাবস্ক্রিপশন ব্যবহার দেখতে provider CLI-তে সাইন ইন করুন।';

  @override
  String get providerUnavailableMessage =>
      'লাইভ ব্যবহারের তথ্য সাময়িকভাবে পাওয়া যাচ্ছে না।';

  @override
  String get installAndSignIn => 'ইনস্টল ও সাইন ইন';

  @override
  String get openSetupGuide => 'সেটআপ গাইড খুলুন';

  @override
  String get signIn => 'সাইন ইন';

  @override
  String get checkAgain => 'আবার যাচাই করুন';

  @override
  String get signInStartedTitle => 'সাইন ইন সম্পন্ন করুন';

  @override
  String signInStartedMessage(String provider) {
    return 'টার্মিনালে $provider-এর সাইন ইন সম্পন্ন করুন। অ্যাপটি স্বয়ংক্রিয়ভাবে আবার সংযোগ করবে।';
  }

  @override
  String get setupFailedTitle => 'সেটআপ সম্পন্ন হয়নি';

  @override
  String get wingetUnavailable =>
      'Windows App Installer (WinGet) পাওয়া যায়নি। নিরাপদে provider ইনস্টল করতে সেটআপ গাইড খুলুন।';

  @override
  String get automaticSetupUnavailable =>
      'এই প্ল্যাটফর্মে স্বয়ংক্রিয় ইনস্টল পাওয়া যায় না। অফিসিয়াল সেটআপ গাইড খুলুন।';

  @override
  String providerSetupFailed(String provider) {
    return '$provider সেটআপ করা যায়নি। অফিসিয়াল সেটআপ গাইড খুলে আবার চেষ্টা করুন।';
  }

  @override
  String get warningThresholdsTooltip =>
      'ব্যবহার ৫০%, ২০% ও ১০% বাকি থাকলে; ৫ ঘণ্টার লিমিটে ১ ঘণ্টা, ৩০ ও ১০ মিনিট আগে; উইকলি লিমিটে ১ দিন, ১২, ৫ ও ১ ঘণ্টা আগে; এবং লিমিট পুনরায় চালু হলে নোটিফিকেশন';

  @override
  String get settingsTooltip => 'নোটিফিকেশন ও স্টার্টআপ সেটিংস';

  @override
  String get firstRunSetupTitle => 'অ্যাপ সেটআপ সম্পন্ন করুন';

  @override
  String get firstRunSetupDescription =>
      'সতর্কতা এবং সাইন ইন করার পর অ্যাপটি স্বয়ংক্রিয়ভাবে খুলবে কি না, তা বেছে নিন।';

  @override
  String get settingsTitle => 'অ্যাপ সেটিংস';

  @override
  String get settingsDescription =>
      'নোটিফিকেশন ও স্টার্টআপের পছন্দ যেকোনো সময় পরিবর্তন করতে পারবেন।';

  @override
  String get notificationAlertsTitle => 'ব্যবহারের নোটিফিকেশন';

  @override
  String get notificationAlertsDescription =>
      'ব্যবহার ৫০%, ২০% ও ১০% বাকি থাকলে; ৫ ঘণ্টার লিমিটে ১ ঘণ্টা, ৩০ ও ১০ মিনিট আগে; উইকলি লিমিটে ১ দিন, ১২, ৫ ও ১ ঘণ্টা আগে; এবং লিমিট পুনরায় চালু হলে নোটিফিকেশন পান।';

  @override
  String get launchAtStartupTitle => 'স্টার্টআপে চালু করুন';

  @override
  String get launchAtStartupDescription =>
      'সাইন ইন করার পর AI Limit Status স্বয়ংক্রিয়ভাবে খুলুন।';

  @override
  String get done => 'সম্পন্ন';

  @override
  String get settingsUpdateFailedTitle => 'সেটিং পরিবর্তন হয়নি';

  @override
  String get settingsUpdateFailed =>
      'সেটিংটি পরিবর্তন করা যায়নি। আবার চেষ্টা করুন।';

  @override
  String get notificationPermissionDenied =>
      'নোটিফিকেশন পারমিশন বন্ধ আছে। সিস্টেমের নোটিফিকেশন সেটিংসে AI Limit Status-কে অনুমতি দিন।';

  @override
  String get startupApprovalRequired =>
      'সিস্টেমের Login Items বা Startup Apps সেটিংসে AI Limit Status-কে অনুমোদন দিন।';

  @override
  String get startupUnsupported =>
      'এই অপারেটিং সিস্টেম ভার্সনে স্বয়ংক্রিয় স্টার্টআপ সমর্থিত নয়।';

  @override
  String get openSystemSettings => 'সেটিংস খুলুন';

  @override
  String usageWarningTitle(String provider) {
    return '$provider ব্যবহারের সতর্কতা';
  }

  @override
  String resetWarningTitle(String provider) {
    return '$provider রিসেটের রিমাইন্ডার';
  }

  @override
  String remainingFiftyWarningBody(String limit, int percent) {
    return 'আপনার $limit-এ $percent% বাকি আছে। সতর্কভাবে ব্যবহার করুন।';
  }

  @override
  String remainingTwentyWarningBody(String limit, int percent) {
    return '⚠️ আপনার $limit-এ মাত্র $percent% বাকি আছে। আরও সতর্কভাবে ব্যবহার করুন।';
  }

  @override
  String remainingTenWarningBody(String limit, int percent) {
    return '⚠️ আপনার $limit-এ মাত্র $percent% বাকি আছে। ব্যবহার কমিয়ে দিন।';
  }

  @override
  String resetOneDayWarningBody(String limit) {
    return 'আপনার $limit রিসেট হতে আর ১ দিন বাকি।';
  }

  @override
  String resetTwelveHoursWarningBody(String limit) {
    return 'আপনার $limit রিসেট হতে আর ১২ ঘণ্টা বাকি।';
  }

  @override
  String resetFiveHoursWarningBody(String limit) {
    return 'আপনার $limit রিসেট হতে আর ৫ ঘণ্টা বাকি।';
  }

  @override
  String resetOneHourWarningBody(String limit) {
    return 'আপনার $limit রিসেট হতে আর ১ ঘণ্টা বাকি।';
  }

  @override
  String resetThirtyMinutesWarningBody(String limit) {
    return 'আপনার $limit রিসেট হতে আর ৩০ মিনিট বাকি।';
  }

  @override
  String resetTenMinutesWarningBody(String limit) {
    return 'আপনার $limit রিসেট হতে আর ১০ মিনিট বাকি।';
  }

  @override
  String limitRestoredTitle(String provider) {
    return '$provider লিমিট পুনরায় চালু হয়েছে';
  }

  @override
  String limitRestoredBody(String limit) {
    return '$limit আবার চালু হয়েছে।';
  }

  @override
  String get openDashboard => 'বিস্তারিত খুলুন';

  @override
  String get quit => 'বন্ধ করুন';

  @override
  String trayTitle(String codexValue, String claudeValue) {
    return '$codexValue · $claudeValue';
  }

  @override
  String trayTooltip(String codexValue, String claudeValue) {
    return 'Codex: $codexValue · Claude ৫ ঘণ্টা: $claudeValue';
  }

  @override
  String singleProviderTrayTooltip(String provider, String value) {
    return '$provider: $value';
  }
}
