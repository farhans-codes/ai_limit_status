import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ai_limit_status/core/constants/app_strings.dart';
import 'package:ai_limit_status/features/settings/presentation/controllers/desktop_settings_controller.dart';

class DesktopSettingsDialog extends StatelessWidget {
  const DesktopSettingsDialog({
    required this.controller,
    required this.firstRun,
    super.key,
  });

  final DesktopSettingsController controller;
  final bool firstRun;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.instance;
    return PopScope(
      canPop: !firstRun,
      child: AlertDialog(
        title: Text(
          firstRun ? strings.firstRunSetupTitle : strings.settingsTitle,
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  firstRun
                      ? strings.firstRunSetupDescription
                      : strings.settingsDescription,
                ),
                const SizedBox(height: 14),
                Obx(
                  () => SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    secondary: const Icon(Icons.notifications_active_outlined),
                    title: Text(strings.notificationAlertsTitle),
                    subtitle: Text(strings.notificationAlertsDescription),
                    value: controller.notificationsEnabled.value,
                    onChanged: controller.isUpdating.value
                        ? null
                        : controller.setNotificationsEnabled,
                  ),
                ),
                Obx(
                  () => SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    secondary: const Icon(Icons.power_settings_new_rounded),
                    title: Text(strings.launchAtStartupTitle),
                    subtitle: Text(strings.launchAtStartupDescription),
                    value: controller.launchAtStartupEnabled.value,
                    onChanged: controller.isUpdating.value
                        ? null
                        : controller.setLaunchAtStartupEnabled,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          Obx(
            () => FilledButton(
              onPressed: controller.isUpdating.value ? null : controller.finish,
              child: Text(strings.done),
            ),
          ),
        ],
      ),
    );
  }
}
