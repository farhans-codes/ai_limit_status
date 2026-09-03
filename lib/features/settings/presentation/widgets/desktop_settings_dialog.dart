import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ai_limit_status/core/constants/app_strings.dart';
import 'package:ai_limit_status/features/settings/domain/entities/desktop_settings.dart';
import 'package:ai_limit_status/features/settings/presentation/controllers/desktop_settings_controller.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DesktopSettingsDialog extends StatelessWidget {
  const DesktopSettingsDialog({
    required this.controller,
    required this.firstRun,
    super.key,
  });

  final DesktopSettingsController controller;
  final bool firstRun;

  static final Future<String> _version = PackageInfo.fromPlatform().then(
    (info) => info.version,
  );

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.instance;
    final theme = Theme.of(context);
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
                const SizedBox(height: 8),
                Obx(
                  () => DropdownButtonFormField<ClaudeStatusLimitPreference>(
                    initialValue: controller.claudeStatusLimitPreference.value,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.speed_rounded),
                      labelText: strings.claudeShortcutLimitTitle,
                      helperText: strings.claudeShortcutLimitDescription,
                      helperMaxLines: 2,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: ClaudeStatusLimitPreference.fiveHour,
                        child: Text(strings.claudeFiveHourShortcut),
                      ),
                      DropdownMenuItem(
                        value: ClaudeStatusLimitPreference.fableWeekly,
                        child: Text(strings.claudeFableShortcut),
                      ),
                    ],
                    onChanged: controller.isUpdating.value
                        ? null
                        : (preference) {
                            if (preference != null) {
                              controller.setClaudeStatusLimitPreference(
                                preference,
                              );
                            }
                          },
                  ),
                ),
                const Divider(),
                Text(
                  strings.providersSectionTitle,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  strings.providerVisibilityDescription,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Obx(
                  () => SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: Text(strings.showCodexTitle),
                    value: controller.visibleProviders.contains(
                      UsageProvider.codex,
                    ),
                    onChanged: controller.isUpdating.value
                        ? null
                        : (visible) => controller.setProviderVisible(
                            UsageProvider.codex,
                            visible,
                          ),
                  ),
                ),
                Obx(
                  () => SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: Text(strings.showClaudeTitle),
                    value: controller.visibleProviders.contains(
                      UsageProvider.claude,
                    ),
                    onChanged: controller.isUpdating.value
                        ? null
                        : (visible) => controller.setProviderVisible(
                            UsageProvider.claude,
                            visible,
                          ),
                  ),
                ),
                const Divider(),
                FutureBuilder<String>(
                  future: _version,
                  builder: (context, snapshot) {
                    final version = snapshot.data;
                    if (version == null) {
                      return const SizedBox.shrink();
                    }
                    return Text(
                      strings.appVersion(version),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );
                  },
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
