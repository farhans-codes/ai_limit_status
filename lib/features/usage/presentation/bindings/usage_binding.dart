import 'package:get/get.dart';
import 'package:ai_limit_status/core/platform/app_window_service.dart';
import 'package:ai_limit_status/core/platform/desktop_notification_service.dart';
import 'package:ai_limit_status/core/platform/mac_status_bar_service.dart';
import 'package:ai_limit_status/core/platform/tray_service.dart';
import 'package:ai_limit_status/features/usage/data/datasources/provider_executable_locator.dart';
import 'package:ai_limit_status/features/usage/data/datasources/usage_data_source.dart';
import 'package:ai_limit_status/features/usage/data/datasources/claude_usage_reader.dart';
import 'package:ai_limit_status/features/usage/data/datasources/codex_usage_reader.dart';
import 'package:ai_limit_status/features/usage/data/datasources/usage_warning_state_store.dart';
import 'package:ai_limit_status/features/usage/data/repositories/provider_setup_repository_impl.dart';
import 'package:ai_limit_status/features/usage/data/repositories/usage_repository_impl.dart';
import 'package:ai_limit_status/features/usage/data/repositories/usage_warning_repository_impl.dart';
import 'package:ai_limit_status/features/usage/domain/repositories/provider_setup_repository.dart';
import 'package:ai_limit_status/features/usage/domain/repositories/usage_repository.dart';
import 'package:ai_limit_status/features/usage/domain/repositories/usage_warning_repository.dart';
import 'package:ai_limit_status/features/usage/domain/usecases/evaluate_usage_warnings.dart';
import 'package:ai_limit_status/features/usage/domain/usecases/get_usage_summary.dart';
import 'package:ai_limit_status/features/usage/domain/usecases/install_provider.dart';
import 'package:ai_limit_status/features/usage/domain/usecases/open_provider_setup_guide.dart';
import 'package:ai_limit_status/features/usage/domain/usecases/show_usage_warning.dart';
import 'package:ai_limit_status/features/usage/domain/usecases/sign_in_provider.dart';
import 'package:ai_limit_status/features/usage/presentation/controllers/usage_controller.dart';

class UsageBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<TrayService>(
      TrayService(Get.find<AppWindowService>(), MacStatusBarService()),
      permanent: true,
    );
    Get.lazyPut<ProviderExecutableLocator>(ProviderExecutableLocator.new);
    Get.lazyPut<CodexUsageReader>(
      () => CodexUsageReader(Get.find<ProviderExecutableLocator>()),
    );
    Get.lazyPut<ClaudeUsageReader>(
      () => ClaudeUsageReader(Get.find<ProviderExecutableLocator>()),
    );
    Get.lazyPut<UsageDataSource>(
      () => LiveUsageDataSource(
        Get.find<CodexUsageReader>(),
        Get.find<ClaudeUsageReader>(),
      ),
    );
    Get.lazyPut<UsageRepository>(
      () => UsageRepositoryImpl(Get.find<UsageDataSource>()),
    );
    Get.lazyPut<GetUsageSummary>(
      () => GetUsageSummary(Get.find<UsageRepository>()),
    );
    Get.lazyPut<ProviderSetupRepository>(
      () => ProviderSetupRepositoryImpl(Get.find<ProviderExecutableLocator>()),
    );
    Get.lazyPut<InstallProvider>(
      () => InstallProvider(Get.find<ProviderSetupRepository>()),
    );
    Get.lazyPut<SignInProvider>(
      () => SignInProvider(Get.find<ProviderSetupRepository>()),
    );
    Get.lazyPut<OpenProviderSetupGuide>(
      () => OpenProviderSetupGuide(Get.find<ProviderSetupRepository>()),
    );
    Get.lazyPut<DesktopNotificationService>(DesktopNotificationService.new);
    Get.lazyPut<UsageWarningStateStore>(UsageWarningStateStore.new);
    Get.lazyPut<UsageWarningRepository>(
      () => UsageWarningRepositoryImpl(
        Get.find<DesktopNotificationService>(),
        Get.find<UsageWarningStateStore>(),
      ),
    );
    Get.lazyPut<EvaluateUsageWarnings>(EvaluateUsageWarnings.new);
    Get.lazyPut<ShowUsageWarning>(
      () => ShowUsageWarning(Get.find<UsageWarningRepository>()),
    );
    Get.lazyPut<UsageController>(
      () => UsageController(
        Get.find<GetUsageSummary>(),
        Get.find<TrayService>(),
        Get.find<InstallProvider>(),
        Get.find<SignInProvider>(),
        Get.find<OpenProviderSetupGuide>(),
        Get.find<EvaluateUsageWarnings>(),
        Get.find<ShowUsageWarning>(),
      ),
    );
  }
}
