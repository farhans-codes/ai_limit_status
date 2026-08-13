import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

enum UsageWarningKind { remaining, reset }

class UsageWarning {
  const UsageWarning({
    required this.provider,
    required this.limitType,
    required this.kind,
    required this.threshold,
    required this.currentRemainingPercent,
    required this.resetsAt,
  });

  final UsageProvider provider;
  final UsageLimitType limitType;
  final UsageWarningKind kind;
  final int threshold;
  final int currentRemainingPercent;
  final DateTime? resetsAt;

  String get identifier {
    final window = resetsAt?.toUtc().millisecondsSinceEpoch ?? 'unknown';
    return '${provider.name}:${limitType.name}:$window:${kind.name}:$threshold';
  }
}
