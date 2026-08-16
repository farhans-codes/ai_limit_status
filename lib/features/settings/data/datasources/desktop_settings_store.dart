import 'dart:convert';
import 'dart:io';

class StoredDesktopSettings {
  const StoredDesktopSettings({
    required this.notificationsEnabled,
    required this.notificationPreferenceConfigured,
    required this.onboardingCompleted,
  });

  const StoredDesktopSettings.defaults()
    : notificationsEnabled = false,
      notificationPreferenceConfigured = false,
      onboardingCompleted = false;

  final bool notificationsEnabled;
  final bool notificationPreferenceConfigured;
  final bool onboardingCompleted;

  StoredDesktopSettings copyWith({
    bool? notificationsEnabled,
    bool? notificationPreferenceConfigured,
    bool? onboardingCompleted,
  }) {
    return StoredDesktopSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationPreferenceConfigured:
          notificationPreferenceConfigured ??
          this.notificationPreferenceConfigured,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  Map<String, bool> toJson() => {
    'notificationsEnabled': notificationsEnabled,
    'notificationPreferenceConfigured': notificationPreferenceConfigured,
    'onboardingCompleted': onboardingCompleted,
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
      );
    } on Object {
      return const StoredDesktopSettings.defaults();
    }
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
