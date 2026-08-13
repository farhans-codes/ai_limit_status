import 'package:ai_limit_status/features/usage/data/datasources/usage_data_source.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';
import 'package:ai_limit_status/features/usage/domain/repositories/usage_repository.dart';

class UsageRepositoryImpl implements UsageRepository {
  const UsageRepositoryImpl(this._dataSource);

  final UsageDataSource _dataSource;

  @override
  Future<List<ProviderUsage>> fetchUsage() => _dataSource.fetchUsage();
}
