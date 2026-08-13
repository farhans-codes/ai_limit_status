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
      '৫০% ও ২০% বাকি থাকলে এবং রিসেটের ৫ ঘণ্টা ও ১ ঘণ্টা আগে সতর্কতা';

  @override
  String usageWarningTitle(String provider) {
    return '$provider ব্যবহারের সতর্কতা';
  }

  @override
  String resetWarningTitle(String provider) {
    return '$provider রিসেটের রিমাইন্ডার';
  }

  @override
  String remainingWarningBody(String limit, int percent, int threshold) {
    return '$limit-এ $percent% বাকি আছে ($threshold% সতর্কতা)।';
  }

  @override
  String resetWarningBody(String limit, int hours) {
    return '$limit আগামী $hours ঘণ্টার মধ্যে রিসেট হবে।';
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
}
