import 'dart:io';

import 'package:flutter/services.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

enum StartupRegistrationResult {
  enabled,
  disabled,
  requiresApproval,
  unsupported,
  failed,
}

class DesktopStartupService {
  static const _macChannel = MethodChannel('com.ailimitstatus/startup');

  bool _isConfigured = false;

  bool get isSupported => Platform.isMacOS || Platform.isWindows;

  void setup(String appName) {
    if (_isConfigured) {
      return;
    }
    if (Platform.isWindows) {
      launchAtStartup.setup(
        appName: appName,
        appPath: Platform.resolvedExecutable,
      );
    }
    _isConfigured = true;
  }

  Future<bool> isEnabled() async {
    if (!isSupported) {
      return false;
    }
    try {
      if (Platform.isMacOS) {
        return await _macChannel.invokeMethod<bool>('isEnabled') ?? false;
      }
      return await launchAtStartup.isEnabled();
    } on Object {
      return false;
    }
  }

  Future<StartupRegistrationResult> setEnabled(bool enabled) async {
    if (!isSupported) {
      return StartupRegistrationResult.unsupported;
    }
    try {
      if (Platform.isMacOS) {
        final status = await _macChannel.invokeMethod<String>('setEnabled', {
          'enabled': enabled,
        });
        return switch (status) {
          'enabled' => StartupRegistrationResult.enabled,
          'disabled' => StartupRegistrationResult.disabled,
          'requiresApproval' => StartupRegistrationResult.requiresApproval,
          'unsupported' => StartupRegistrationResult.unsupported,
          _ => StartupRegistrationResult.failed,
        };
      }

      if (enabled) {
        await launchAtStartup.enable();
      } else {
        await launchAtStartup.disable();
      }
      final isNowEnabled = await launchAtStartup.isEnabled();
      if (isNowEnabled == enabled) {
        return enabled
            ? StartupRegistrationResult.enabled
            : StartupRegistrationResult.disabled;
      }
      return StartupRegistrationResult.failed;
    } on Object {
      return StartupRegistrationResult.failed;
    }
  }
}
