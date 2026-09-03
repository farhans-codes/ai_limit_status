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
                if (controller.supportsManualClaudeSession ||
                    controller.supportsBrowserBridge) ...[
                  const Divider(),
                  _ClaudeSessionSection(controller: controller),
                ],
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

class _ClaudeSessionSection extends StatefulWidget {
  const _ClaudeSessionSection({required this.controller});

  final DesktopSettingsController controller;

  @override
  State<_ClaudeSessionSection> createState() => _ClaudeSessionSectionState();
}

class _ClaudeSessionSectionState extends State<_ClaudeSessionSection> {
  final _sessionKeyController = TextEditingController();

  @override
  void dispose() {
    _sessionKeyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (await widget.controller.saveManualClaudeSessionKey(
      _sessionKeyController.text,
    )) {
      _sessionKeyController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.instance;
    final theme = Theme.of(context);
    final controller = widget.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.claudeSessionSectionTitle,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          strings.claudeSessionSectionDescription,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (controller.supportsBrowserBridge) ...[
          const SizedBox(height: 10),
          Obx(() {
            final connected = controller.browserBridgeConnected.value;
            final label = connected == null
                ? strings.browserBridgeChecking
                : connected
                ? strings.browserBridgeConnected
                : strings.browserBridgeNotDetected;
            final color = connected == true
                ? const Color(0xFF3ED78A)
                : theme.colorScheme.onSurfaceVariant;
            return Row(
              children: [
                Icon(Icons.extension_rounded, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${strings.browserBridgeStatusLabel}: $label'),
                ),
                IconButton(
                  tooltip: strings.checkAgain,
                  visualDensity: VisualDensity.compact,
                  onPressed: controller.refreshBrowserBridgeStatus,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                ),
              ],
            );
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: controller.openBrowserExtensionFolder,
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: Text(strings.openExtensionFolder),
            ),
          ),
          Text(
            strings.browserBridgeHowTo,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (controller.supportsManualClaudeSession) ...[
          const SizedBox(height: 12),
          Obx(
            () => TextField(
              controller: _sessionKeyController,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              enabled: !controller.isUpdating.value,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.key_rounded),
                labelText: strings.claudeSessionKeyLabel,
                hintText: strings.claudeSessionKeyHint,
                helperText: controller.hasManualClaudeSessionKey.value
                    ? strings.claudeSessionKeyStored
                    : null,
                helperMaxLines: 2,
              ),
              onSubmitted: (_) => _save(),
            ),
          ),
          const SizedBox(height: 8),
          Obx(
            () => Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (controller.hasManualClaudeSessionKey.value)
                  TextButton(
                    onPressed: controller.isUpdating.value
                        ? null
                        : controller.clearManualClaudeSessionKey,
                    child: Text(strings.clearSessionKey),
                  ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: controller.isUpdating.value ? null : _save,
                  child: Text(strings.saveSessionKey),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
