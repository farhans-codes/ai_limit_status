import 'dart:convert';

import 'package:ai_limit_status/features/settings/data/datasources/desktop_settings_store.dart';
import 'package:ai_limit_status/features/settings/domain/entities/desktop_settings.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every provider is visible by default', () {
    const settings = StoredDesktopSettings.defaults();
    expect(settings.hiddenProviders, isEmpty);
    expect(settings.visibleProviders, UsageProvider.values.toSet());
  });

  test('hidden providers round-trip through JSON', () {
    const settings = StoredDesktopSettings(
      notificationsEnabled: true,
      notificationPreferenceConfigured: true,
      onboardingCompleted: true,
      claudeStatusLimitPreference: ClaudeStatusLimitPreference.fableWeekly,
      hiddenProviders: {UsageProvider.claude},
    );

    final json = jsonDecode(jsonEncode(settings.toJson()));

    expect(json['hiddenProviders'], ['claude']);
    expect(json['claudeStatusLimitPreference'], 'fableWeekly');
    expect(settings.visibleProviders, {UsageProvider.codex});
  });

  test('copyWith replaces the hidden set', () {
    const settings = StoredDesktopSettings.defaults();
    final hidden = settings.copyWith(hiddenProviders: {UsageProvider.codex});
    expect(hidden.visibleProviders, {UsageProvider.claude});
    expect(
      hidden.copyWith(hiddenProviders: {}).visibleProviders,
      UsageProvider.values.toSet(),
    );
  });
}
