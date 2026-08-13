import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

abstract interface class UsageRepository {
  Future<List<ProviderUsage>> fetchUsage();
}
