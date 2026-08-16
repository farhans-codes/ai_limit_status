import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ai_limit_status/features/settings/presentation/controllers/desktop_settings_controller.dart';
import 'package:ai_limit_status/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: !firstRun,
      child: AlertDialog(
        title: Text(firstRun ? l10n.firstRunSetupTitle : l10n.settingsTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  firstRun
                      ? l10n.firstRunSetupDescription
                      : l10n.settingsDescription,
                ),
                const SizedBox(height: 14),
                Obx(
                  () => SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    secondary: const Icon(Icons.notifications_active_outlined),
                    title: Text(l10n.notificationAlertsTitle),
                    subtitle: Text(l10n.notificationAlertsDescription),
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
                    title: Text(l10n.launchAtStartupTitle),
                    subtitle: Text(l10n.launchAtStartupDescription),
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
              child: Text(l10n.done),
            ),
          ),
        ],
      ),
    );
  }
}
