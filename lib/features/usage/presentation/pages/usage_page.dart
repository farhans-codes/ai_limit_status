import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ai_limit_status/core/constants/app_strings.dart';
import 'package:ai_limit_status/features/settings/presentation/controllers/desktop_settings_controller.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';
import 'package:ai_limit_status/features/usage/presentation/controllers/usage_controller.dart';
import 'package:ai_limit_status/features/usage/presentation/widgets/provider_details_card.dart';

class UsagePage extends GetView<UsageController> {
  const UsagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.instance;
    final settingsController = Get.find<DesktopSettingsController>();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [Color(0x621A1E28), Color(0x480C1018)]
                    : const [Color(0x86F9FBFF), Color(0x6EE8EDF7)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.20)
                    : Colors.white.withValues(alpha: 0.88),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: -90,
                  top: -105,
                  child: _AmbientGlow(
                    color: colorScheme.primary.withValues(
                      alpha: isDark ? 0.14 : 0.10,
                    ),
                    size: 260,
                  ),
                ),
                Positioned(
                  right: -100,
                  bottom: -120,
                  child: _AmbientGlow(
                    color: const Color(
                      0xFF2ECDB1,
                    ).withValues(alpha: isDark ? 0.08 : 0.06),
                    size: 250,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 11, 6, 14),
                  child: Obx(() {
                    if (controller.isLoading.value &&
                        controller.usages.isEmpty) {
                      return _LoadingState(label: l10n.loadingUsage);
                    }

                    if (controller.hasError.value &&
                        controller.usages.isEmpty) {
                      return _ErrorState(
                        message: l10n.unableToLoadUsage,
                        retryLabel: l10n.retry,
                        onRetry: controller.refreshUsage,
                      );
                    }

                    if (controller.usages.isEmpty) {
                      return _NoProvidersState(
                        title: l10n.noProvidersDetected,
                        message: l10n.noProvidersDetectedDescription,
                        codexLabel: l10n.setUpProvider(l10n.providerCodex),
                        claudeLabel: l10n.setUpProvider(l10n.providerClaude),
                        isCodexLoading: controller.isSettingUp(
                          UsageProvider.codex,
                        ),
                        isClaudeLoading: controller.isSettingUp(
                          UsageProvider.claude,
                        ),
                        onSetupCodex: () =>
                            controller.installProvider(UsageProvider.codex),
                        onSetupClaude: () =>
                            controller.installProvider(UsageProvider.claude),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _Header(
                            title: l10n.appTitle,
                            settingsTooltip: l10n.settingsTooltip,
                            refreshTooltip: l10n.refresh,
                            isRefreshing: controller.isLoading.value,
                            onSettings: settingsController.openSettings,
                            onRefresh: controller.refreshUsage,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: _GlassDivider(),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.only(right: 8),
                            itemCount: controller.usages.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 11),
                            itemBuilder: (context, index) {
                              final usage = controller.usages[index];
                              return ProviderDetailsCard(
                                usage: usage,
                                automaticSetupAvailable:
                                    controller.supportsAutomaticInstall,
                                isSetupInProgress: controller.isSettingUp(
                                  usage.provider,
                                ),
                                onInstall: () =>
                                    controller.installProvider(usage.provider),
                                onSignIn: () =>
                                    controller.signInProvider(usage.provider),
                                onOpenSetupGuide: () =>
                                    controller.openSetupGuide(usage.provider),
                                onCheckAgain: controller.refreshUsage,
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoProvidersState extends StatelessWidget {
  const _NoProvidersState({
    required this.title,
    required this.message,
    required this.codexLabel,
    required this.claudeLabel,
    required this.isCodexLoading,
    required this.isClaudeLoading,
    required this.onSetupCodex,
    required this.onSetupClaude,
  });

  final String title;
  final String message;
  final String codexLabel;
  final String claudeLabel;
  final bool isCodexLoading;
  final bool isClaudeLoading;
  final VoidCallback onSetupCodex;
  final VoidCallback onSetupClaude;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.extension_off_outlined, size: 32),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: isCodexLoading ? null : onSetupCodex,
                child: _SetupButtonLabel(
                  label: codexLabel,
                  isLoading: isCodexLoading,
                ),
              ),
              OutlinedButton(
                onPressed: isClaudeLoading ? null : onSetupClaude,
                child: _SetupButtonLabel(
                  label: claudeLabel,
                  isLoading: isClaudeLoading,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SetupButtonLabel extends StatelessWidget {
  const _SetupButtonLabel({required this.label, required this.isLoading});

  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (!isLoading) {
      return Text(label);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(
          dimension: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.settingsTooltip,
    required this.refreshTooltip,
    required this.isRefreshing,
    required this.onSettings,
    required this.onRefresh,
  });

  final String title;
  final String settingsTooltip;
  final String refreshTooltip;
  final bool isRefreshing;
  final VoidCallback onSettings;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colorScheme.primary, const Color(0xFF2ECDB1)],
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.42),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.25,
            ),
          ),
        ),
        _GlassHeaderButton(
          tooltip: settingsTooltip,
          onPressed: onSettings,
          child: const Icon(Icons.tune_rounded, size: 18),
        ),
        const SizedBox(width: 7),
        _GlassHeaderButton(
          tooltip: refreshTooltip,
          onPressed: isRefreshing ? null : onRefresh,
          child: isRefreshing
              ? const SizedBox.square(
                  dimension: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded, size: 18),
        ),
      ],
    );
  }
}

class _GlassHeaderButton extends StatelessWidget {
  const _GlassHeaderButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Colors.white.withValues(alpha: 0.10),
                    Colors.white.withValues(alpha: 0.035),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.80),
                    Colors.white.withValues(alpha: 0.42),
                  ],
          ),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.72),
          ),
        ),
        child: SizedBox.square(
          dimension: 34,
          child: IconButton(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            onPressed: onPressed,
            icon: child,
          ),
        ),
      ),
    );
  }
}

class _GlassDivider extends StatelessWidget {
  const _GlassDivider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: isDark ? 0.18 : 0.75),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(label),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 30),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}
