import 'package:ai_limit_status/features/usage/domain/entities/provider_setup_result.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';
import 'package:ai_limit_status/features/usage/domain/repositories/provider_setup_repository.dart';

class SignInProvider {
  const SignInProvider(this._repository);

  final ProviderSetupRepository _repository;

  Future<ProviderSetupResult> call(UsageProvider provider) {
    return _repository.signIn(provider);
  }
}
