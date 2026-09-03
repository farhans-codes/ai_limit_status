enum UsageProvider { codex, claude }

enum UsageLimitType { session, weekly, fableWeekly, opusWeekly, sonnetWeekly }

enum UsageConnectionIssue {
  /// No provider CLI and no other credential source was found.
  cliNotFound,

  /// The CLI is installed (or a credential store exists) but holds no valid
  /// sign-in, or the provider rejected the stored token permanently.
  notSignedIn,

  /// A claude.ai browser session was available but the provider rejected it;
  /// the user must sign in to claude.ai again (or paste a new session key).
  browserSessionExpired,

  /// claude.ai answered with a Cloudflare challenge (typically VPN or
  /// datacenter networks). Signing in again does not help.
  browserBlocked,

  /// A temporary failure; the last successful snapshot is kept when present.
  unavailable,
}

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
    required this.isInstalled,
    required this.fetchedAt,
    this.isStale = false,
    this.connectionIssue,
  });

  final UsageProvider provider;
  final List<UsageLimit> limits;
  final bool isConnected;
  final bool isInstalled;
  final DateTime fetchedAt;
  final bool isStale;
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
