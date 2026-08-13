import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ai_limit_status/features/usage/presentation/controllers/usage_controller.dart';
import 'package:ai_limit_status/features/usage/presentation/widgets/provider_details_card.dart';
import 'package:ai_limit_status/l10n/app_localizations.dart';

class UsagePage extends GetView<UsageController> {
  const UsagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [Color(0xB81B1E24), Color(0xA614161B)]
                        : const [Color(0xC7F6F8FC), Color(0xB5E7EBF3)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 10, 13, 13),
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
                      return _ErrorState(
                        message: l10n.unableToLoadUsage,
                        retryLabel: l10n.retry,
                        onRetry: controller.refreshUsage,
                      );
                    }

                    final hasStaleData = controller.usages.any(
                      (usage) => usage.isStale,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Header(
                          title: l10n.appTitle,
                          liveLabel: hasStaleData
                              ? l10n.cachedData
                              : l10n.liveData,
                          isLive: !hasStaleData,
                          warningsTooltip: l10n.warningThresholdsTooltip,
                          refreshTooltip: l10n.refresh,
                          isRefreshing: controller.isLoading.value,
                          onRefresh: controller.refreshUsage,
                        ),
                        Divider(
                          height: 15,
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.only(top: 2),
                            itemCount: controller.usages.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.liveLabel,
    required this.isLive,
    required this.warningsTooltip,
    required this.refreshTooltip,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final String title;
  final String liveLabel;
  final bool isLive;
  final String warningsTooltip;
  final String refreshTooltip;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final statusColor = isLive
        ? const Color(0xFF2B8A57)
        : const Color(0xFFC06B16);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            liveLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Tooltip(
          message: warningsTooltip,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 5),
            child: Icon(Icons.notifications_active_outlined, size: 17),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: refreshTooltip,
          onPressed: isRefreshing ? null : onRefresh,
          icon: isRefreshing
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded, size: 19),
        ),
      ],
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
