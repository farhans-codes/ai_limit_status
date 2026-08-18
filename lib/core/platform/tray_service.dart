import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:ai_limit_status/core/platform/app_window_service.dart';
import 'package:ai_limit_status/core/platform/mac_status_bar_service.dart';
import 'package:ai_limit_status/core/platform/windows_taskbar_status_service.dart';
import 'package:tray_manager/tray_manager.dart';

class TrayMenuCopy {
  const TrayMenuCopy({
    required this.openDashboard,
    required this.refresh,
    required this.quit,
    required this.initialTooltip,
  });

  final String openDashboard;
  final String refresh;
  final String quit;
  final String initialTooltip;
}

class TrayService extends GetxService with TrayListener {
  TrayService(
    this._windowService,
    this._macStatusBarService,
    this._windowsTaskbarStatusService,
  );

  static const _openKey = 'open_dashboard';
  static const _refreshKey = 'refresh_usage';
  static const _quitKey = 'quit_app';

  final AppWindowService _windowService;
  final MacStatusBarService _macStatusBarService;
  final WindowsTaskbarStatusService _windowsTaskbarStatusService;
  Future<void> Function()? _onRefresh;
  bool _isInitialized = false;
  final Completer<void> _ready = Completer<void>();

  Future<void> get whenReady => _ready.future;

  Future<void> initialize({
    required TrayMenuCopy copy,
    required Future<void> Function() onRefresh,
  }) async {
    if (_isInitialized) {
      return;
    }

    _onRefresh = onRefresh;

    if (Platform.isMacOS) {
      await _macStatusBarService.initialize(
        openLabel: copy.openDashboard,
        refreshLabel: copy.refresh,
        quitLabel: copy.quit,
        initialTooltip: copy.initialTooltip,
        onRefresh: onRefresh,
        onQuit: _quit,
        onWillShow: _windowService.prepareForNativeShow,
      );
      _isInitialized = true;
      _ready.complete();
      return;
    }

    if (Platform.isWindows) {
      await _windowsTaskbarStatusService.initialize(
        openLabel: copy.openDashboard,
        refreshLabel: copy.refresh,
        quitLabel: copy.quit,
        initialTooltip: copy.initialTooltip,
        onToggle: _windowService.togglePopover,
        onShow: _windowService.showPopover,
        onRefresh: onRefresh,
        onQuit: _quit,
      );
      _isInitialized = true;
      _ready.complete();
      return;
    }

    trayManager.addListener(this);

    await trayManager.setIcon(
      'windows/runner/resources/app_icon.ico',
      iconSize: 18,
    );
    await trayManager.setToolTip(copy.initialTooltip);
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: _openKey, label: copy.openDashboard),
          MenuItem(key: _refreshKey, label: copy.refresh),
          MenuItem.separator(),
          MenuItem(key: _quitKey, label: copy.quit),
        ],
      ),
    );

    _isInitialized = true;
    _ready.complete();
  }

  Future<void> showDashboard() async {
    await whenReady;
    if (Platform.isMacOS) {
      await _macStatusBarService.show();
      return;
    }
    if (Platform.isWindows) {
      await _windowService.showPopover();
      return;
    }
    await _windowService.showPopover();
  }

  Future<void> updateUsage({
    required String? codexValue,
    required String? claudeValue,
    required String tooltip,
  }) async {
    if (!_isInitialized) {
      return;
    }
    if (Platform.isMacOS) {
      await _macStatusBarService.update(
        codexValue: codexValue,
        claudeValue: claudeValue,
        tooltip: tooltip,
      );
      return;
    }
    if (Platform.isWindows) {
      await _windowsTaskbarStatusService.update(
        codexValue: codexValue,
        claudeValue: claudeValue,
        tooltip: tooltip,
      );
      return;
    }
    await trayManager.setToolTip(tooltip);
  }

  @override
  void onTrayIconMouseDown() {
    _windowService.togglePopover();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _openKey:
        _windowService.showPopover();
      case _refreshKey:
        _onRefresh?.call();
      case _quitKey:
        _quit();
    }
  }

  Future<void> _quit() async {
    if (Platform.isMacOS) {
      await _macStatusBarService.destroy();
    } else if (Platform.isWindows) {
      await _windowsTaskbarStatusService.destroy();
    } else {
      await trayManager.destroy();
    }
    await _windowService.quit();
  }

  @override
  void onClose() {
    if (!Platform.isMacOS && !Platform.isWindows) {
      trayManager.removeListener(this);
    }
    super.onClose();
  }
}
