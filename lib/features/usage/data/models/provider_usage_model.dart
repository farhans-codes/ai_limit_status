import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

class ProviderUsageModel extends ProviderUsage {
  const ProviderUsageModel({
    required super.provider,
    required super.limits,
    required super.isConnected,
    required super.fetchedAt,
    super.isStale,
    super.connectionIssue,
  });

  ProviderUsageModel asStale() {
    return ProviderUsageModel(
      provider: provider,
      limits: limits,
      isConnected: isConnected,
      fetchedAt: fetchedAt,
      isStale: true,
      connectionIssue: connectionIssue,
    );
  }

  factory ProviderUsageModel.disconnected({
    required UsageProvider provider,
    required UsageConnectionIssue issue,
  }) {
    return ProviderUsageModel(
      provider: provider,
      limits: const [],
      isConnected: false,
      fetchedAt: DateTime.now(),
      connectionIssue: issue,
    );
  }
}
