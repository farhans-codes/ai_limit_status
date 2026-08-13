enum UsageProvider { codex, claude }

enum UsageLimitType { session, weekly, opusWeekly, sonnetWeekly }

enum UsageConnectionIssue { cliNotFound, notSignedIn, unavailable }

class UsageLimit {
  const UsageLimit({
    required this.type,
    required this.remainingPercent,
    this.resetsAt,
  });

  final UsageLimitType type;
  final int remainingPercent;
  final DateTime? resetsAt;
}

class ProviderUsage {
  const ProviderUsage({
    required this.provider,
    required this.limits,
    required this.isConnected,
    required this.fetchedAt,
    this.connectionIssue,
  });

  final UsageProvider provider;
  final List<UsageLimit> limits;
  final bool isConnected;
  final DateTime fetchedAt;
  final UsageConnectionIssue? connectionIssue;

  int? remainingFor(UsageLimitType type) {
    for (final limit in limits) {
      if (limit.type == type) {
        return limit.remainingPercent;
      }
    }
    return null;
  }

  int? get mostUrgentRemaining {
    if (limits.isEmpty) {
      return null;
    }

    return limits
        .map((limit) => limit.remainingPercent)
        .reduce((current, next) => current < next ? current : next);
  }
}
