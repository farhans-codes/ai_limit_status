import 'package:ai_limit_status/features/usage/domain/entities/provider_setup_result.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';
import 'package:ai_limit_status/features/usage/domain/repositories/provider_setup_repository.dart';

class InstallProvider {
  const InstallProvider(this._repository);

  final ProviderSetupRepository _repository;

  bool get isSupported => _repository.supportsAutomaticInstall;

  Future<ProviderSetupResult> call(UsageProvider provider) {
    return _repository.install(provider);
  }
}
