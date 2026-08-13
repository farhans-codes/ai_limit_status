import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';
import 'package:ai_limit_status/features/usage/domain/repositories/usage_repository.dart';

class GetUsageSummary {
  const GetUsageSummary(this._repository);

  final UsageRepository _repository;

  Future<List<ProviderUsage>> call() => _repository.fetchUsage();
}
