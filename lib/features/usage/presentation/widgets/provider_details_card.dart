import 'package:flutter/material.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';
import 'package:ai_limit_status/features/usage/presentation/widgets/provider_icon.dart';
import 'package:ai_limit_status/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    final providerName = usage.provider == UsageProvider.codex
        ? l10n.providerCodex
        : l10n.providerClaude;
    final statusColor = usage.isConnected
        ? const Color(0xFF2B8A57)
        : Theme.of(context).colorScheme.error;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerLow.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.58),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ProviderIcon(provider: usage.provider, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    providerName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Icons.circle, size: 8, color: statusColor),
                const SizedBox(width: 6),
                Text(
                  usage.isConnected ? l10n.connected : l10n.disconnected,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (usage.isConnected)
              for (var index = 0; index < usage.limits.length; index++) ...[
                if (index > 0) const SizedBox(height: 16),
                _LimitMetric(
                  label: _limitLabel(l10n, usage.limits[index].type),
                  limit: usage.limits[index],
                ),
              ]
            else
              _DisconnectedMessage(
                message: _connectionMessage(l10n, usage.connectionIssue),
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
            const SizedBox(height: 8),
            Divider(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: Text(_lastUpdatedLabel(l10n, usage.fetchedAt))),
                Text(l10n.autoRefreshMinutes(1), textAlign: TextAlign.end),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LimitMetric extends StatelessWidget {
  const _LimitMetric({required this.label, required this.limit});

  final String label;
  final UsageLimit limit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final indicatorColor = _indicatorColor(context, limit.remainingPercent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              l10n.remainingLabel(limit.remainingPercent),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: indicatorColor,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        LinearProgressIndicator(
          minHeight: 8,
          value: limit.remainingPercent / 100,
          color: indicatorColor,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        const SizedBox(height: 7),
        Text(
          limit.resetsAt == null
              ? l10n.resetTimeUnavailable
              : _resetLabel(l10n, limit.resetsAt!),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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
  AppLocalizations l10n,
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

Color _indicatorColor(BuildContext context, int percentage) {
  if (percentage <= 20) {
    return Theme.of(context).colorScheme.error;
  }
  if (percentage <= 50) {
    return const Color(0xFFC06B16);
  }
  return Theme.of(context).colorScheme.primary;
}

String _resetLabel(AppLocalizations l10n, DateTime resetsAt) {
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

String _lastUpdatedLabel(AppLocalizations l10n, DateTime fetchedAt) {
  final elapsed = DateTime.now().difference(fetchedAt);
  if (elapsed.inMinutes < 1) {
    return l10n.lastUpdatedNow;
  }
  return l10n.lastUpdatedMinutes(elapsed.inMinutes);
}

String _limitLabel(AppLocalizations l10n, UsageLimitType type) {
  return switch (type) {
    UsageLimitType.session => l10n.fiveHourLimit,
    UsageLimitType.weekly => l10n.weeklyLimit,
    UsageLimitType.opusWeekly => l10n.opusWeeklyLimit,
    UsageLimitType.sonnetWeekly => l10n.sonnetWeeklyLimit,
  };
}

String _connectionMessage(AppLocalizations l10n, UsageConnectionIssue? issue) {
  return switch (issue) {
    UsageConnectionIssue.cliNotFound => l10n.cliNotFoundMessage,
    UsageConnectionIssue.notSignedIn => l10n.notSignedInMessage,
    UsageConnectionIssue.unavailable || null => l10n.providerUnavailableMessage,
  };
}
