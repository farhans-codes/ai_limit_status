import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';
import 'package:ai_limit_status/features/usage/domain/entities/usage_warning.dart';

class EvaluateUsageWarnings {
  const EvaluateUsageWarnings();

  static const remainingThresholds = [20, 50];
  static const resetThresholdHours = [1, 5];

  List<UsageWarning> call(List<ProviderUsage> usages, {DateTime? currentTime}) {
    final now = currentTime ?? DateTime.now();
    final warnings = <UsageWarning>[];

    for (final usage in usages.where(
      (item) => item.isConnected && !item.isStale,
    )) {
      for (final limit in usage.limits) {
        final remainingThreshold = _firstMatchingThreshold(
          remainingThresholds,
          limit.remainingPercent,
        );
        if (remainingThreshold != null) {
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

        final resetsAt = limit.resetsAt;
        if (resetsAt == null) {
          continue;
        }
        final minutesUntilReset = resetsAt.difference(now).inMinutes;
        if (minutesUntilReset <= 0) {
          continue;
        }
        final resetThreshold = _firstMatchingThreshold(
          resetThresholdHours.map((hours) => hours * 60),
          minutesUntilReset,
        );
        if (resetThreshold != null) {
          warnings.add(
            UsageWarning(
              provider: usage.provider,
              limitType: limit.type,
              kind: UsageWarningKind.reset,
              threshold: resetThreshold ~/ 60,
              currentRemainingPercent: limit.remainingPercent,
              resetsAt: resetsAt,
            ),
          );
        }
      }
    }
    return warnings;
  }

  int? _firstMatchingThreshold(Iterable<int> thresholds, int value) {
    for (final threshold in thresholds) {
      if (value <= threshold) {
        return threshold;
      }
    }
    return null;
  }
}
