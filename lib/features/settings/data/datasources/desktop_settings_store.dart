import 'dart:convert';
import 'dart:io';

import 'package:ai_limit_status/features/settings/domain/entities/desktop_settings.dart';

class StoredDesktopSettings {
  const StoredDesktopSettings({
    required this.notificationsEnabled,
    required this.notificationPreferenceConfigured,
    required this.onboardingCompleted,
    required this.claudeStatusLimitPreference,
  });

  const StoredDesktopSettings.defaults()
    : notificationsEnabled = false,
      notificationPreferenceConfigured = false,
      onboardingCompleted = false,
      claudeStatusLimitPreference = ClaudeStatusLimitPreference.fiveHour;

  final bool notificationsEnabled;
  final bool notificationPreferenceConfigured;
  final bool onboardingCompleted;
  final ClaudeStatusLimitPreference claudeStatusLimitPreference;

  StoredDesktopSettings copyWith({
    bool? notificationsEnabled,
    bool? notificationPreferenceConfigured,
    bool? onboardingCompleted,
    ClaudeStatusLimitPreference? claudeStatusLimitPreference,
  }) {
    return StoredDesktopSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationPreferenceConfigured:
          notificationPreferenceConfigured ??
          this.notificationPreferenceConfigured,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      claudeStatusLimitPreference:
          claudeStatusLimitPreference ?? this.claudeStatusLimitPreference,
    );
  }

  Map<String, Object> toJson() => {
    'notificationsEnabled': notificationsEnabled,
    'notificationPreferenceConfigured': notificationPreferenceConfigured,
    'onboardingCompleted': onboardingCompleted,
    'claudeStatusLimitPreference': claudeStatusLimitPreference.name,
  };
}

class DesktopSettingsStore {
  Future<StoredDesktopSettings> read() async {
    final file = _settingsFile();
    try {
      if (!await file.exists()) {
        return const StoredDesktopSettings.defaults();
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return const StoredDesktopSettings.defaults();
      }
      return StoredDesktopSettings(
        notificationsEnabled: decoded['notificationsEnabled'] == true,
        notificationPreferenceConfigured:
            decoded['notificationPreferenceConfigured'] == true,
        onboardingCompleted: decoded['onboardingCompleted'] == true,
        claudeStatusLimitPreference: _parseClaudeStatusLimitPreference(
          decoded['claudeStatusLimitPreference'],
        ),
      );
    } on Object {
      return const StoredDesktopSettings.defaults();
    }
  }

  ClaudeStatusLimitPreference _parseClaudeStatusLimitPreference(Object? value) {
    return ClaudeStatusLimitPreference.values.firstWhere(
      (preference) => preference.name == value,
      orElse: () => ClaudeStatusLimitPreference.fiveHour,
    );
  }

  Future<void> write(StoredDesktopSettings settings) async {
    final file = _settingsFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(settings.toJson()), flush: true);
  }

  File _settingsFile() {
    final environment = Platform.environment;
    if (Platform.isWindows) {
      final base = environment['LOCALAPPDATA'] ?? environment['USERPROFILE'];
      if (base != null) {
        return File('$base\\AI Limit Status\\desktop_settings.json');
      }
    }
    final userHome = environment['HOME'];
    if (Platform.isMacOS && userHome != null) {
      return File(
        '$userHome/Library/Application Support/AI Limit Status/desktop_settings.json',
      );
    }
    final dataHome = environment['XDG_DATA_HOME'];
    if (dataHome != null) {
      return File('$dataHome/ai_limit_status/desktop_settings.json');
    }
    if (userHome != null) {
      return File(
        '$userHome/.local/share/ai_limit_status/desktop_settings.json',
      );
    }
    return File(
      '${Directory.systemTemp.path}/ai_limit_status/desktop_settings.json',
    );
  }
}
