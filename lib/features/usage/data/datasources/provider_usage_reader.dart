import 'package:ai_limit_status/features/usage/data/models/provider_usage_model.dart';

/// Reads one provider's current usage.
///
/// Throw a `UsageReadException` with the matching `UsageConnectionIssue` when
/// usage cannot be read; `LiveUsageDataSource` turns it into a disconnected
/// card or falls back to the last cached result. See
/// `docs/adding-a-provider.md`.
abstract interface class ProviderUsageReader {
  Future<ProviderUsageModel> read();
}
