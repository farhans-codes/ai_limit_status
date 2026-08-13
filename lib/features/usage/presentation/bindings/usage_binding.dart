import 'package:get/get.dart';
import 'package:ai_limit_status/core/platform/app_window_service.dart';
import 'package:ai_limit_status/core/platform/mac_status_bar_service.dart';
import 'package:ai_limit_status/core/platform/tray_service.dart';
import 'package:ai_limit_status/features/usage/data/datasources/usage_data_source.dart';
import 'package:ai_limit_status/features/usage/data/datasources/claude_usage_reader.dart';
import 'package:ai_limit_status/features/usage/data/datasources/codex_usage_reader.dart';
import 'package:ai_limit_status/features/usage/data/repositories/usage_repository_impl.dart';
import 'package:ai_limit_status/features/usage/domain/repositories/usage_repository.dart';
import 'package:ai_limit_status/features/usage/domain/usecases/get_usage_summary.dart';
import 'package:ai_limit_status/features/usage/presentation/controllers/usage_controller.dart';

class UsageBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<TrayService>(
      TrayService(Get.find<AppWindowService>(), MacStatusBarService()),
      permanent: true,
    );
    Get.lazyPut<CodexUsageReader>(CodexUsageReader.new);
    Get.lazyPut<ClaudeUsageReader>(ClaudeUsageReader.new);
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
    Get.lazyPut<UsageController>(
      () =>
          UsageController(Get.find<GetUsageSummary>(), Get.find<TrayService>()),
    );
  }
}
