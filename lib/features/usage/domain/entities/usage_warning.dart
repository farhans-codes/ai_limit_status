import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

enum UsageWarningKind { remaining, resetSoon, restored }

class UsageWarning {
  const UsageWarning({
    required this.provider,
    required this.limitType,
    this.groupId,
    this.groupLabel,
    required this.kind,
    required this.threshold,
    required this.currentRemainingPercent,
    required this.resetsAt,
  });

  final UsageProvider provider;
  final UsageLimitType limitType;
  final String? groupId;
  final String? groupLabel;
  final UsageWarningKind kind;
  final int threshold;
  final int currentRemainingPercent;
  final DateTime? resetsAt;

  String get identifier {
    final resetTime = resetsAt?.toUtc();
    final window = resetTime == null
        ? 'unknown'
        : resetTime.millisecondsSinceEpoch ~/ _windowDuration.inMilliseconds;
    // Ungrouped limits keep their original identifier so warnings already
    // shown by earlier versions are not repeated.
    final limit = groupId == null
        ? limitType.name
        : '$groupId:${limitType.name}';
    return '${provider.name}:$limit:$window:${kind.name}:$threshold';
  }

  Duration get _windowDuration => switch (limitType) {
    UsageLimitType.session => const Duration(hours: 5),
    UsageLimitType.weekly ||
    UsageLimitType.fableWeekly ||
    UsageLimitType.opusWeekly ||
    UsageLimitType.sonnetWeekly => const Duration(days: 7),
  };
}
