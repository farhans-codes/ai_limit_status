import 'dart:ui';

import 'package:ai_limit_status/core/constants/app_strings.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';
import 'package:ai_limit_status/features/usage/presentation/widgets/provider_icon.dart';
import 'package:flutter/material.dart';

class ProviderDetailsCard extends StatelessWidget {
  const ProviderDetailsCard({
    required this.usage,
    required this.automaticSetupAvailable,
    required this.isSetupInProgress,
    required this.onInstall,
    required this.onSignIn,
    required this.onOpenSetupGuide,
    required this.onCheckAgain,
    super.key,
  });

  final ProviderUsage usage;
  final bool automaticSetupAvailable;
  final bool isSetupInProgress;
  final VoidCallback onInstall;
  final VoidCallback onSignIn;
  final VoidCallback onOpenSetupGuide;
  final VoidCallback onCheckAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.instance;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final providerName = usage.provider == UsageProvider.codex
        ? l10n.providerCodex
        : l10n.providerClaude;
    final providerAccent = usage.provider == UsageProvider.codex
        ? const Color(0xFF42C7B2)
        : const Color(0xFFE7835B);
    final statusColor = usage.isStale
        ? const Color(0xFFE2A341)
        : usage.isConnected
        ? const Color(0xFF3ED78A)
        : theme.colorScheme.error;
    final statusLabel = usage.isStale
        ? l10n.cachedData
        : usage.isConnected
        ? l10n.connected
        : l10n.disconnected;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.10),
            blurRadius: 18,
            spreadRadius: -8,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: providerAccent.withValues(alpha: isDark ? 0.10 : 0.07),
            blurRadius: 22,
            spreadRadius: -12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Colors.white.withValues(alpha: 0.065),
                        providerAccent.withValues(alpha: 0.018),
                        Colors.white.withValues(alpha: 0.018),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.54),
                        providerAccent.withValues(alpha: 0.035),
                        Colors.white.withValues(alpha: 0.24),
                      ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.80),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -48,
                  top: -52,
                  child: _CardGlow(
                    color: providerAccent.withValues(
                      alpha: isDark ? 0.055 : 0.04,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: [
                                BoxShadow(
                                  color: providerAccent.withValues(alpha: 0.22),
                                  blurRadius: 13,
                                  spreadRadius: -4,
                                ),
                              ],
                            ),
                            child: ProviderIcon(
                              provider: usage.provider,
                              size: 29,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              providerName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.15,
                              ),
                            ),
                          ),
                          _StatusPill(label: statusLabel, color: statusColor),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (usage.isConnected)
                        for (
                          var index = 0;
                          index < usage.limits.length;
                          index++
                        ) ...[
                          if (index > 0) const SizedBox(height: 16),
                          _LimitMetric(
                            label: _limitLabel(l10n, usage.limits[index].type),
                            limit: usage.limits[index],
                            providerAccent: providerAccent,
                          ),
                        ]
                      else
                        _DisconnectedMessage(
                          message: _connectionMessage(
                            l10n,
                            usage.connectionIssue,
                          ),
                          primaryLabel: _primarySetupLabel(
                            l10n,
                            usage.connectionIssue,
                            automaticSetupAvailable,
                          ),
                          primaryIcon: _primarySetupIcon(
                            usage.connectionIssue,
                            automaticSetupAvailable,
                          ),
                          onPrimary: _primarySetupAction(
                            usage.connectionIssue,
                            automaticSetupAvailable,
                            onInstall: onInstall,
                            onSignIn: onSignIn,
                            onOpenSetupGuide: onOpenSetupGuide,
                          ),
                          checkAgainLabel: l10n.checkAgain,
                          onCheckAgain: onCheckAgain,
                          isSetupInProgress: isSetupInProgress,
                        ),
                      const SizedBox(height: 12),
                      const _GlassDivider(),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _lastUpdatedLabel(l10n, usage.fetchedAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.44), blurRadius: 7),
              ],
            ),
            child: const SizedBox.square(dimension: 6),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LimitMetric extends StatelessWidget {
  const _LimitMetric({
    required this.label,
    required this.limit,
    required this.providerAccent,
  });

  final String label;
  final UsageLimit limit;
  final Color providerAccent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppStrings.instance;
    final theme = Theme.of(context);
    final indicatorColor = _indicatorColor(
      context,
      limit.remainingPercent,
      providerAccent,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: indicatorColor.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: indicatorColor.withValues(alpha: 0.16),
                ),
              ),
              child: Text(
                l10n.remainingLabel(limit.remainingPercent),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: indicatorColor,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        _GlassProgressBar(
          value: limit.remainingPercent / 100,
          color: indicatorColor,
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Icon(
              Icons.update_rounded,
              size: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                limit.resetsAt == null
                    ? l10n.resetTimeUnavailable
                    : _resetLabel(l10n, limit.resetsAt!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GlassProgressBar extends StatelessWidget {
  const _GlassProgressBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 9,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.42),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.07 : 0.70),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.72), color],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.50),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
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
            Colors.white.withValues(alpha: isDark ? 0.13 : 0.68),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _CardGlow extends StatelessWidget {
  const _CardGlow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.square(
        dimension: 150,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}

class _DisconnectedMessage extends StatelessWidget {
  const _DisconnectedMessage({
    required this.message,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    required this.checkAgainLabel,
    required this.onCheckAgain,
    required this.isSetupInProgress,
  });

  final String message;
  final String? primaryLabel;
  final IconData? primaryIcon;
  final VoidCallback? onPrimary;
  final String checkAgainLabel;
  final VoidCallback onCheckAgain;
  final bool isSetupInProgress;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 92),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onPrimary != null && primaryLabel != null)
                FilledButton.icon(
                  onPressed: isSetupInProgress ? null : onPrimary,
                  icon: isSetupInProgress
                      ? const SizedBox.square(
                          dimension: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(primaryIcon, size: 17),
                  label: Text(primaryLabel!),
                ),
              OutlinedButton.icon(
                onPressed: isSetupInProgress ? null : onCheckAgain,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: Text(checkAgainLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String? _primarySetupLabel(
  AppStrings l10n,
  UsageConnectionIssue? issue,
  bool automaticSetupAvailable,
) {
  return switch (issue) {
    UsageConnectionIssue.cliNotFound =>
      automaticSetupAvailable ? l10n.installAndSignIn : l10n.openSetupGuide,
    UsageConnectionIssue.notSignedIn => l10n.signIn,
    UsageConnectionIssue.unavailable || null => null,
  };
}

IconData? _primarySetupIcon(
  UsageConnectionIssue? issue,
  bool automaticSetupAvailable,
) {
  return switch (issue) {
    UsageConnectionIssue.cliNotFound =>
      automaticSetupAvailable
          ? Icons.download_rounded
          : Icons.open_in_new_rounded,
    UsageConnectionIssue.notSignedIn => Icons.login_rounded,
    UsageConnectionIssue.unavailable || null => null,
  };
}

VoidCallback? _primarySetupAction(
  UsageConnectionIssue? issue,
  bool automaticSetupAvailable, {
  required VoidCallback onInstall,
  required VoidCallback onSignIn,
  required VoidCallback onOpenSetupGuide,
}) {
  return switch (issue) {
    UsageConnectionIssue.cliNotFound =>
      automaticSetupAvailable ? onInstall : onOpenSetupGuide,
    UsageConnectionIssue.notSignedIn => onSignIn,
    UsageConnectionIssue.unavailable || null => null,
  };
}

Color _indicatorColor(
  BuildContext context,
  int percentage,
  Color providerAccent,
) {
  if (percentage <= 20) {
    return Theme.of(context).colorScheme.error;
  }
  if (percentage <= 50) {
    return const Color(0xFFE2A341);
  }
  return providerAccent;
}

String _resetLabel(AppStrings l10n, DateTime resetsAt) {
  final remaining = resetsAt.difference(DateTime.now());
  if (remaining.isNegative || remaining.inMinutes == 0) {
    return l10n.resettingSoon;
  }
  if (remaining.inDays > 0) {
    return l10n.resetsInDaysHours(
      remaining.inDays,
      remaining.inHours.remainder(24),
    );
  }
  return l10n.resetsInHoursMinutes(
    remaining.inHours,
    remaining.inMinutes.remainder(60),
  );
}

String _lastUpdatedLabel(AppStrings l10n, DateTime fetchedAt) {
  final elapsed = DateTime.now().difference(fetchedAt);
  if (elapsed.inMinutes < 1) {
    return l10n.lastUpdatedNow;
  }
  return l10n.lastUpdatedMinutes(elapsed.inMinutes);
}

String _limitLabel(AppStrings l10n, UsageLimitType type) {
  return switch (type) {
    UsageLimitType.session => l10n.fiveHourLimit,
    UsageLimitType.weekly => l10n.weeklyLimit,
    UsageLimitType.fableWeekly => l10n.fableWeeklyLimit,
    UsageLimitType.opusWeekly => l10n.opusWeeklyLimit,
    UsageLimitType.sonnetWeekly => l10n.sonnetWeeklyLimit,
  };
}

String _connectionMessage(AppStrings l10n, UsageConnectionIssue? issue) {
  return switch (issue) {
    UsageConnectionIssue.cliNotFound => l10n.cliNotFoundMessage,
    UsageConnectionIssue.notSignedIn => l10n.notSignedInMessage,
    UsageConnectionIssue.unavailable || null => l10n.providerUnavailableMessage,
  };
}
