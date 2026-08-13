import 'dart:async';

import 'package:get/get.dart';
import 'package:ai_limit_status/core/platform/tray_service.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';
import 'package:ai_limit_status/features/usage/domain/usecases/get_usage_summary.dart';
import 'package:ai_limit_status/l10n/app_localizations.dart';

class UsageController extends GetxController {
  UsageController(this._getUsageSummary, this._trayService);

  static const refreshInterval = Duration(minutes: 1);

  final GetUsageSummary _getUsageSummary;
  final TrayService _trayService;

  final usages = <ProviderUsage>[].obs;
  final isLoading = true.obs;
  final hasError = false.obs;

  Timer? _refreshTimer;
  bool _isRefreshing = false;

  @override
  void onReady() {
    super.onReady();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final context = Get.context;
    if (context == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    await _trayService.initialize(
      copy: TrayMenuCopy(
        openDashboard: l10n.openDashboard,
        refresh: l10n.refresh,
        quit: l10n.quit,
        initialTooltip: l10n.appTitle,
        unavailableValue: l10n.notAvailableCompact,
      ),
      onRefresh: refreshUsage,
    );
    await refreshUsage();
    _refreshTimer = Timer.periodic(refreshInterval, (_) => refreshUsage());
  }

  Future<void> refreshUsage() async {
    if (_isRefreshing) {
      return;
    }

    _isRefreshing = true;
    isLoading.value = usages.isEmpty;
    hasError.value = false;

    try {
      usages.assignAll(await _getUsageSummary());
      await _updateTray();
    } on Object {
      hasError.value = true;
    } finally {
      isLoading.value = false;
      _isRefreshing = false;
    }
  }

  Future<void> _updateTray() async {
    final context = Get.context;
    if (context == null || usages.length < 2) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final codex = usages.firstWhere(
      (usage) => usage.provider == UsageProvider.codex,
    );
    final claude = usages.firstWhere(
      (usage) => usage.provider == UsageProvider.claude,
    );
    final codexValue = _compactValue(l10n, codex);
    final claudeValue = _compactValue(
      l10n,
      claude,
      preferredType: UsageLimitType.session,
    );
    await _trayService.updateUsage(
      codexValue: codexValue,
      claudeValue: claudeValue,
      tooltip: l10n.trayTooltip(codexValue, claudeValue),
    );
  }

  String _compactValue(
    AppLocalizations l10n,
    ProviderUsage usage, {
    UsageLimitType? preferredType,
  }) {
    final remaining = preferredType == null
        ? usage.mostUrgentRemaining
        : usage.remainingFor(preferredType) ?? usage.mostUrgentRemaining;
    return remaining == null
        ? l10n.notAvailableCompact
        : l10n.remainingCompact(remaining);
  }

  @override
  void onClose() {
    _refreshTimer?.cancel();
    super.onClose();
  }
}
