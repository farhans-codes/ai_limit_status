import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';
import 'package:ai_limit_status/features/usage/domain/entities/usage_warning.dart';

class EvaluateUsageWarnings {
  const EvaluateUsageWarnings();

  static const remainingThresholds = [10, 20, 50];
  static const fiveHourResetThresholdMinutes = [10, 30, 60];
  static const weeklyResetThresholdMinutes = [60, 300, 720, 1440];
  static const _minimumRestoredIncrease = 5;

  List<UsageWarning> call(
    List<ProviderUsage> usages, {
    List<ProviderUsage> previousUsages = const [],
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    final warnings = <UsageWarning>[];
    final previousByProvider = {
      for (final usage in previousUsages) usage.provider: usage,
    };

    for (final usage in usages.where(
      (item) => item.isConnected && !item.isStale,
    )) {
      final previousUsage = previousByProvider[usage.provider];
      for (final limit in usage.limits) {
        final previousLimit = _findLimit(previousUsage, limit.type);
        final remainingThreshold = _firstMatchingThreshold(
          remainingThresholds,
          limit.remainingPercent,
        );
        if (remainingThreshold != null &&
            _enteredRemainingThreshold(previousLimit, remainingThreshold)) {
          warnings.add(
            UsageWarning(
              provider: usage.provider,
              limitType: limit.type,
              kind: UsageWarningKind.remaining,
              threshold: remainingThreshold,
              currentRemainingPercent: limit.remainingPercent,
              resetsAt: limit.resetsAt,
            ),
          );
        }

        final resetThresholds = _resetThresholdsFor(usage.provider, limit.type);
        if (resetThresholds.isNotEmpty && _wasRestored(previousLimit, limit)) {
          warnings.add(
            UsageWarning(
              provider: usage.provider,
              limitType: limit.type,
              kind: UsageWarningKind.restored,
              threshold: 100,
              currentRemainingPercent: limit.remainingPercent,
              resetsAt: limit.resetsAt,
            ),
          );
        }

        final resetsAt = limit.resetsAt;
        if (resetsAt == null || resetThresholds.isEmpty) {
          continue;
        }
        final timeUntilReset = resetsAt.difference(now);
        if (timeUntilReset <= Duration.zero) {
          continue;
        }
        final resetThreshold = _firstMatchingResetThreshold(
          resetThresholds,
          timeUntilReset,
        );
        if (resetThreshold != null &&
            _enteredResetThreshold(
              previousUsage,
              previousLimit,
              resetThreshold,
            )) {
          warnings.add(
            UsageWarning(
              provider: usage.provider,
              limitType: limit.type,
              kind: UsageWarningKind.resetSoon,
              threshold: resetThreshold,
              currentRemainingPercent: limit.remainingPercent,
              resetsAt: resetsAt,
            ),
          );
        }
      }
    }
    return warnings;
  }

  UsageLimit? _findLimit(ProviderUsage? usage, UsageLimitType type) {
    if (usage == null || !usage.isConnected || usage.isStale) {
      return null;
    }
    for (final limit in usage.limits) {
      if (limit.type == type) {
        return limit;
      }
    }
    return null;
  }

  bool _enteredRemainingThreshold(UsageLimit? previous, int threshold) {
    return previous == null || previous.remainingPercent > threshold;
  }

  bool _wasRestored(UsageLimit? previous, UsageLimit current) {
    if (previous == null) {
      return false;
    }
    final restoredIncrease =
        current.remainingPercent - previous.remainingPercent;
    return current.remainingPercent == 100 &&
        restoredIncrease >= _minimumRestoredIncrease;
  }

  bool _enteredResetThreshold(
    ProviderUsage? previousUsage,
    UsageLimit? previousLimit,
    int thresholdMinutes,
  ) {
    final previousReset = previousLimit?.resetsAt;
    if (previousUsage == null || previousReset == null) {
      return true;
    }
    return previousReset.difference(previousUsage.fetchedAt) >
        Duration(minutes: thresholdMinutes);
  }

  List<int> _resetThresholdsFor(
    UsageProvider provider,
    UsageLimitType limitType,
  ) {
    return switch (limitType) {
      UsageLimitType.session when provider == UsageProvider.claude =>
        fiveHourResetThresholdMinutes,
      UsageLimitType.session => const [],
      UsageLimitType.weekly ||
      UsageLimitType.opusWeekly ||
      UsageLimitType.sonnetWeekly => weeklyResetThresholdMinutes,
    };
  }

  int? _firstMatchingThreshold(Iterable<int> thresholds, int value) {
    for (final threshold in thresholds) {
      if (value <= threshold) {
        return threshold;
      }
    }
    return null;
  }

  int? _firstMatchingResetThreshold(
    Iterable<int> thresholds,
    Duration timeUntilReset,
  ) {
    for (final threshold in thresholds) {
      if (timeUntilReset <= Duration(minutes: threshold)) {
        return threshold;
      }
    }
    return null;
  }
}
