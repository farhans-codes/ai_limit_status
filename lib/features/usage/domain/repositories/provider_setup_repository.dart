import 'package:ai_limit_status/features/usage/domain/entities/provider_setup_result.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

abstract interface class ProviderSetupRepository {
  bool get supportsAutomaticInstall;

  Future<ProviderSetupResult> install(UsageProvider provider);

  Future<ProviderSetupResult> signIn(UsageProvider provider);

  Future<ProviderSetupResult> openSetupGuide(UsageProvider provider);
}
