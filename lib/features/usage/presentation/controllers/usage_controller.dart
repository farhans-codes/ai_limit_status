import 'dart:async';

import 'package:get/get.dart';
import 'package:ai_limit_status/core/constants/app_strings.dart';
import 'package:ai_limit_status/core/platform/tray_service.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_setup_result.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';
import 'package:ai_limit_status/features/usage/domain/entities/usage_warning.dart';
import 'package:ai_limit_status/features/usage/domain/usecases/evaluate_usage_warnings.dart';
import 'package:ai_limit_status/features/usage/domain/usecases/get_usage_summary.dart';
import 'package:ai_limit_status/features/usage/domain/usecases/install_provider.dart';
import 'package:ai_limit_status/features/usage/domain/usecases/open_provider_setup_guide.dart';
import 'package:ai_limit_status/features/usage/domain/usecases/show_usage_warning.dart';
import 'package:ai_limit_status/features/usage/domain/usecases/sign_in_provider.dart';

class UsageController extends GetxController {
  UsageController(
    this._getUsageSummary,
    this._trayService,
    this._installProvider,
    this._signInProvider,
    this._openProviderSetupGuide,
    this._evaluateUsageWarnings,
    this._showUsageWarning,
  );

  static const refreshInterval = Duration(minutes: 1);

  final GetUsageSummary _getUsageSummary;
  final TrayService _trayService;
  final InstallProvider _installProvider;
  final SignInProvider _signInProvider;
  final OpenProviderSetupGuide _openProviderSetupGuide;
  final EvaluateUsageWarnings _evaluateUsageWarnings;
  final ShowUsageWarning _showUsageWarning;

  final usages = <ProviderUsage>[].obs;
  final isLoading = true.obs;
  final hasError = false.obs;
  final setupProviders = <UsageProvider>{}.obs;

  Timer? _refreshTimer;
  final Map<UsageProvider, Timer> _connectionPollingTimers = {};
  bool _isRefreshing = false;

  bool get supportsAutomaticInstall => _installProvider.isSupported;

  bool isSettingUp(UsageProvider provider) {
    return setupProviders.contains(provider);
  }

  @override
  void onReady() {
    super.onReady();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final l10n = AppStrings.instance;
    await _trayService.initialize(
      copy: TrayMenuCopy(
        openDashboard: l10n.openDashboard,
        refresh: l10n.refresh,
        quit: l10n.quit,
        initialTooltip: l10n.appTitle,
      ),
      onRefresh: refreshUsage,
    );
    await _showUsageWarning.initialize(l10n.appTitle);
    await refreshUsage();
    _refreshTimer = Timer.periodic(refreshInterval, (_) => refreshUsage());
  }

  Future<void> refreshUsage() async {
    if (_isRefreshing) {
      return;
    }

    _isRefreshing = true;
    isLoading.value = true;
    hasError.value = false;

    try {
      final previousUsages = usages.toList(growable: false);
      usages.assignAll(await _getUsageSummary());
      _stopPollingForConnectedProviders();
      await _updateTray();
      await _notifyForThresholds(previousUsages);
    } on Object {
      hasError.value = true;
    } finally {
      isLoading.value = false;
      _isRefreshing = false;
    }
  }

  Future<void> installProvider(UsageProvider provider) async {
    if (isSettingUp(provider)) {
      return;
    }
    _setSetupProgress(provider, true);
    try {
      final result = await _installProvider(provider);
      if (result != ProviderSetupResult.succeeded) {
        _showSetupResult(provider, result);
        await _openProviderSetupGuide(provider);
        return;
      }

      final signInResult = await _signInProvider(provider);
      if (signInResult == ProviderSetupResult.succeeded) {
        _showSignInStarted(provider);
        _startConnectionPolling(provider);
      } else {
        _showSetupResult(provider, signInResult);
        await _openProviderSetupGuide(provider);
      }
      await refreshUsage();
    } finally {
      _setSetupProgress(provider, false);
    }
  }

  Future<void> signInProvider(UsageProvider provider) async {
    if (isSettingUp(provider)) {
      return;
    }
    _setSetupProgress(provider, true);
    try {
      final result = await _signInProvider(provider);
      if (result == ProviderSetupResult.succeeded) {
        _showSignInStarted(provider);
        _startConnectionPolling(provider);
      } else {
        _showSetupResult(provider, result);
      }
    } finally {
      _setSetupProgress(provider, false);
    }
  }

  Future<void> openSetupGuide(UsageProvider provider) async {
    if (isSettingUp(provider)) {
      return;
    }
    _setSetupProgress(provider, true);
    try {
      final result = await _openProviderSetupGuide(provider);
      if (result != ProviderSetupResult.succeeded) {
        _showSetupResult(provider, result);
      }
    } finally {
      _setSetupProgress(provider, false);
    }
  }

  void _setSetupProgress(UsageProvider provider, bool inProgress) {
    if (inProgress) {
      setupProviders.add(provider);
    } else {
      setupProviders.remove(provider);
    }
  }

  void _showSignInStarted(UsageProvider provider) {
    final l10n = _localizations;
    Get.snackbar(
      l10n.signInStartedTitle,
      l10n.signInStartedMessage(_providerName(l10n, provider)),
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 6),
    );
  }

  void _showSetupResult(UsageProvider provider, ProviderSetupResult result) {
    final l10n = _localizations;
    final message = switch (result) {
      ProviderSetupResult.installerUnavailable => l10n.wingetUnavailable,
      ProviderSetupResult.unsupported => l10n.automaticSetupUnavailable,
      ProviderSetupResult.failed => l10n.providerSetupFailed(
        _providerName(l10n, provider),
      ),
      ProviderSetupResult.succeeded => null,
    };
    if (message == null) {
      return;
    }
    Get.snackbar(
      l10n.setupFailedTitle,
      message,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 6),
    );
  }

  void _startConnectionPolling(UsageProvider provider) {
    _connectionPollingTimers.remove(provider)?.cancel();
    var attempts = 0;
    _connectionPollingTimers[provider] = Timer.periodic(
      const Duration(seconds: 10),
      (timer) {
        attempts++;
        if (attempts >= 12) {
          timer.cancel();
          _connectionPollingTimers.remove(provider);
          return;
        }
        unawaited(refreshUsage());
      },
    );
  }

  void _stopPollingForConnectedProviders() {
    for (final usage in usages.where((item) => item.isConnected)) {
      _connectionPollingTimers.remove(usage.provider)?.cancel();
    }
  }

  Future<void> _notifyForThresholds(List<ProviderUsage> previousUsages) async {
    final l10n = _localizations;
    for (final warning in _evaluateUsageWarnings(
      usages,
      previousUsages: previousUsages,
    )) {
      final provider = _providerName(l10n, warning.provider);
      final limit = _limitName(l10n, warning.limitType);
      final title = switch (warning.kind) {
        UsageWarningKind.remaining => l10n.usageWarningTitle(provider),
        UsageWarningKind.resetSoon => l10n.resetWarningTitle(provider),
        UsageWarningKind.restored => l10n.limitRestoredTitle(provider),
      };
      final body = switch (warning.kind) {
        UsageWarningKind.remaining => _remainingWarningBody(
          l10n,
          limit,
          warning.currentRemainingPercent,
          warning.threshold,
        ),
        UsageWarningKind.resetSoon => _resetWarningBody(
          l10n,
          limit,
          warning.threshold,
        ),
        UsageWarningKind.restored => l10n.limitRestoredBody(limit),
      };
      await _showUsageWarning(
        identifier: warning.identifier,
        title: title,
        body: body,
      );
    }
  }

  String _remainingWarningBody(
    AppStrings l10n,
    String limit,
    int currentRemainingPercent,
    int threshold,
  ) {
    return switch (threshold) {
      50 => l10n.remainingFiftyWarningBody(limit, currentRemainingPercent),
      20 => l10n.remainingTwentyWarningBody(limit, currentRemainingPercent),
      _ => l10n.remainingTenWarningBody(limit, currentRemainingPercent),
    };
  }

  String _resetWarningBody(
    AppStrings l10n,
    String limit,
    int thresholdMinutes,
  ) {
    return switch (thresholdMinutes) {
      1440 => l10n.resetOneDayWarningBody(limit),
      720 => l10n.resetTwelveHoursWarningBody(limit),
      300 => l10n.resetFiveHoursWarningBody(limit),
      60 => l10n.resetOneHourWarningBody(limit),
      30 => l10n.resetThirtyMinutesWarningBody(limit),
      _ => l10n.resetTenMinutesWarningBody(limit),
    };
  }

  AppStrings get _localizations => AppStrings.instance;

  String _providerName(AppStrings l10n, UsageProvider provider) {
    return switch (provider) {
      UsageProvider.codex => l10n.providerCodex,
      UsageProvider.claude => l10n.providerClaude,
    };
  }

  String _limitName(AppStrings l10n, UsageLimitType type) {
    return switch (type) {
      UsageLimitType.session => l10n.fiveHourLimit,
      UsageLimitType.weekly => l10n.weeklyLimit,
      UsageLimitType.opusWeekly => l10n.opusWeeklyLimit,
      UsageLimitType.sonnetWeekly => l10n.sonnetWeeklyLimit,
    };
  }

  Future<void> _updateTray() async {
    final l10n = AppStrings.instance;
    final codex = _usageFor(UsageProvider.codex);
    final claude = _usageFor(UsageProvider.claude);
    final codexValue = codex == null ? null : _compactValue(l10n, codex);
    final claudeValue = claude == null
        ? null
        : _compactValue(l10n, claude, preferredType: UsageLimitType.session);
    final tooltip = switch ((codexValue, claudeValue)) {
      (final String codexValue, final String claudeValue) => l10n.trayTooltip(
        codexValue,
        claudeValue,
      ),
      (final String codexValue, null) => l10n.singleProviderTrayTooltip(
        l10n.providerCodex,
        codexValue,
      ),
      (null, final String claudeValue) => l10n.singleProviderTrayTooltip(
        l10n.providerClaude,
        claudeValue,
      ),
      _ => l10n.noProvidersDetected,
    };
    await _trayService.updateUsage(
      codexValue: codexValue,
      claudeValue: claudeValue,
      tooltip: tooltip,
    );
  }

  ProviderUsage? _usageFor(UsageProvider provider) {
    for (final usage in usages) {
      if (usage.provider == provider) {
        return usage;
      }
    }
    return null;
  }

  String _compactValue(
    AppStrings l10n,
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
    for (final timer in _connectionPollingTimers.values) {
      timer.cancel();
    }
    _connectionPollingTimers.clear();
    super.onClose();
  }
}
