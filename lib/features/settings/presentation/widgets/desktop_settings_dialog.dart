import 'package:ai_limit_status/core/constants/app_strings.dart';
import 'package:ai_limit_status/features/settings/domain/entities/desktop_settings.dart';
import 'package:ai_limit_status/features/settings/presentation/controllers/desktop_settings_controller.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
    final theme = Theme.of(context);
    final availableHeight = MediaQuery.sizeOf(context).height - 32;

    return PopScope(
      canPop: !firstRun,
      child: Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: availableHeight,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                      child: Icon(
                        firstRun
                            ? Icons.rocket_launch_outlined
                            : Icons.tune_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            firstRun
                                ? strings.firstRunSetupTitle
                                : strings.settingsTitle,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            firstRun
                                ? strings.firstRunSetupDescription
                                : strings.settingsDescription,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!firstRun)
                      IconButton(
                        tooltip: strings.close,
                        onPressed: Navigator.of(context).pop,
                        icon: const Icon(Icons.close_rounded),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionLabel(strings.generalSettingsSectionTitle),
                      const SizedBox(height: 8),
                      Card(
                        child: Column(
                          children: [
                            Obx(
                              () => _SettingsSwitchTile(
                                icon: Icons.notifications_active_outlined,
                                title: strings.notificationAlertsTitle,
                                description:
                                    strings.notificationAlertsDescription,
                                value: controller.notificationsEnabled.value,
                                onChanged: controller.isUpdating.value
                                    ? null
                                    : controller.setNotificationsEnabled,
                              ),
                            ),
                            const Divider(height: 1),
                            Obx(
                              () => _SettingsSwitchTile(
                                icon: Icons.power_settings_new_rounded,
                                title: strings.launchAtStartupTitle,
                                description: strings.launchAtStartupDescription,
                                value: controller.launchAtStartupEnabled.value,
                                onChanged: controller.isUpdating.value
                                    ? null
                                    : controller.setLaunchAtStartupEnabled,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _SectionLabel(strings.statusShortcutSectionTitle),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SettingsHeader(
                                icon: Icons.speed_rounded,
                                title: strings.claudeShortcutLimitTitle,
                                description:
                                    strings.claudeShortcutLimitDescription,
                              ),
                              const SizedBox(height: 14),
                              Obx(
                                () =>
                                    SegmentedButton<
                                      ClaudeStatusLimitPreference
                                    >(
                                      expandedInsets: EdgeInsets.zero,
                                      segments: [
                                        ButtonSegment(
                                          value: ClaudeStatusLimitPreference
                                              .fiveHour,
                                          label: Text(
                                            strings.claudeFiveHourShortcut,
                                          ),
                                        ),
                                        ButtonSegment(
                                          value: ClaudeStatusLimitPreference
                                              .fableWeekly,
                                          label: Text(
                                            strings.claudeFableShortcut,
                                          ),
                                        ),
                                      ],
                                      selected: {
                                        controller
                                            .claudeStatusLimitPreference
                                            .value,
                                      },
                                      onSelectionChanged:
                                          controller.isUpdating.value
                                          ? null
                                          : (selection) => controller
                                                .setClaudeStatusLimitPreference(
                                                  selection.first,
                                                ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _SectionLabel(strings.providersSectionTitle),
                      const SizedBox(height: 8),
                      Card(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  strings.providerVisibilityDescription,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                            Obx(
                              () => _SettingsSwitchTile(
                                icon: Icons.code_rounded,
                                title: strings.showCodexTitle,
                                value: controller.visibleProviders.contains(
                                  UsageProvider.codex,
                                ),
                                onChanged: controller.isUpdating.value
                                    ? null
                                    : (visible) =>
                                          controller.setProviderVisible(
                                            UsageProvider.codex,
                                            visible,
                                          ),
                              ),
                            ),
                            const Divider(height: 1),
                            Obx(
                              () => _SettingsSwitchTile(
                                icon: Icons.auto_awesome_rounded,
                                title: strings.showClaudeTitle,
                                value: controller.visibleProviders.contains(
                                  UsageProvider.claude,
                                ),
                                onChanged: controller.isUpdating.value
                                    ? null
                                    : (visible) =>
                                          controller.setProviderVisible(
                                            UsageProvider.claude,
                                            visible,
                                          ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                child: Row(
                  children: [
                    const Spacer(),
                    Obx(
                      () => FilledButton(
                        onPressed: controller.isUpdating.value
                            ? null
                            : controller.finish,
                        child: Text(
                          firstRun ? strings.finishSetup : strings.done,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.description,
  });

  final IconData icon;
  final String title;
  final String? description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: description == null ? null : Text(description!),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
