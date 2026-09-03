import 'dart:async';
import 'dart:io';

import 'package:ai_limit_status/core/diagnostics/app_log.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

class AppWindowService extends GetxService with WindowListener {
  static const _windowsBlurGracePeriod = Duration(milliseconds: 150);

  /// How long a native show keeps blur-to-hide suppressed. Showing and
  /// focusing the window from the taskbar overlay produces activation churn
  /// that would otherwise hide it again immediately.
  static const _nativeShowGuardPeriod = Duration(milliseconds: 600);
  static const _windowsTaskbarChannel = MethodChannel(
    'com.ailimitstatus/windows_taskbar_status',
  );

  final Completer<void> _ready = Completer<void>();
  bool _isQuitting = false;
  bool _isShowing = false;
  bool _isModalOpen = false;
  Timer? _nativeShowGuard;
  Timer? _blurHideTimer;

  Future<void> get whenReady => _ready.future;

  Future<void> initialize() async {
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
  }

  void markReady() {
    if (!_ready.isCompleted) {
      _ready.complete();
    }
  }

  void setModalOpen(bool isOpen) {
    _isModalOpen = isOpen;
    if (isOpen) {
      _cancelPendingBlurHide();
    }
  }

  Future<void> showPopover() async {
    _cancelPendingBlurHide();
    if (Platform.isWindows && await _showPopoverNatively()) {
      return;
    }
    await _showPopoverFromDart();
  }

  /// Asks the Windows runner to place and show the window next to the
  /// taskbar indicators. Returns `false` when the runner predates native
  /// popover support so the Dart positioning path can take over.
  Future<bool> _showPopoverNatively() async {
    prepareForNativeShow();
    try {
      final shown = await _windowsTaskbarChannel.invokeMethod<bool>(
        'showPopover',
      );
      AppLog.log('window: native showPopover -> $shown');
      return shown ?? true;
    } on MissingPluginException {
      AppLog.log('window: native showPopover unavailable, using Dart path');
      return false;
    } on PlatformException catch (error) {
      AppLog.log('window: native showPopover failed: ${error.message}');
      return false;
    }
  }

  Future<void> _showPopoverFromDart() async {
    final cursor = await screenRetriever.getCursorScreenPoint();
    final windowSize = await windowManager.getSize();
    final displays = await screenRetriever.getAllDisplays();
    final display = _displayContaining(cursor, displays);
    final visibleOrigin = display.visiblePosition ?? Offset.zero;
    final visibleSize = display.visibleSize ?? display.size;
    final visibleRect = visibleOrigin & visibleSize;

    final opensDownward = cursor.dy < visibleRect.center.dy;
    final preferredX = cursor.dx - (windowSize.width / 2);
    final preferredY = opensDownward
        ? cursor.dy + 14
        : cursor.dy - windowSize.height - 14;
    final maxX = visibleRect.right - windowSize.width;
    final maxY = visibleRect.bottom - windowSize.height;
    final position = Offset(
      preferredX.clamp(visibleRect.left, maxX).toDouble(),
      preferredY.clamp(visibleRect.top, maxY).toDouble(),
    );

    AppLog.log(
      'window: Dart showPopover cursor=$cursor size=$windowSize '
      'visible=$visibleRect position=$position',
    );
    _isShowing = true;
    try {
      await windowManager.setPosition(position);
      await windowManager.show();
      await windowManager.focus();
      await Future<void>.delayed(const Duration(milliseconds: 250));
    } on Object catch (error) {
      AppLog.log('window: Dart showPopover failed: $error');
      rethrow;
    } finally {
      _isShowing = false;
    }
  }

  Future<void> togglePopover() async {
    _cancelPendingBlurHide();
    final isVisible = await windowManager.isVisible();
    AppLog.log('window: togglePopover visible=$isVisible');
    if (isVisible) {
      await windowManager.hide();
      return;
    }
    await showPopover();
  }

  /// Suppresses blur-to-hide while a native (menu bar or taskbar) show is in
  /// flight. Windows reports this through the taskbar channel just before
  /// and after it shows the window; macOS calls it from the status bar.
  void prepareForNativeShow() {
    _cancelPendingBlurHide();
    _nativeShowGuard?.cancel();
    _isShowing = true;
    _nativeShowGuard = Timer(_nativeShowGuardPeriod, () {
      _isShowing = false;
    });
  }

  /// Called when the Windows runner has hidden the window itself.
  void onNativePopoverHidden() {
    _cancelPendingBlurHide();
    _nativeShowGuard?.cancel();
    _isShowing = false;
  }

  Future<void> quit() async {
    _isQuitting = true;
    _cancelPendingBlurHide();
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  @override
  Future<void> onWindowClose() async {
    if (_isQuitting) {
      return;
    }
    if (await windowManager.isPreventClose()) {
      await windowManager.hide();
    }
  }

  @override
  Future<void> onWindowBlur() async {
    if (_isQuitting || _isShowing || _isModalOpen) {
      return;
    }
    if (Platform.isWindows) {
      _scheduleWindowsBlurHide();
      return;
    }
    if (await windowManager.isVisible()) {
      await windowManager.hide();
    }
  }

  @override
  void onWindowFocus() {
    _cancelPendingBlurHide();
  }

  void _scheduleWindowsBlurHide() {
    _cancelPendingBlurHide();
    _blurHideTimer = Timer(_windowsBlurGracePeriod, () async {
      _blurHideTimer = null;
      if (_isQuitting || _isShowing || _isModalOpen) {
        return;
      }
      if (await _isPointerOverWindowsTaskbarUi()) {
        AppLog.log('window: blur ignored, pointer over taskbar UI');
        return;
      }
      if (!_isQuitting &&
          !_isShowing &&
          !_isModalOpen &&
          await windowManager.isVisible()) {
        AppLog.log('window: hiding after blur');
        await windowManager.hide();
      }
    });
  }

  Future<bool> _isPointerOverWindowsTaskbarUi() async {
    if (!Platform.isWindows) {
      return false;
    }
    try {
      return await _windowsTaskbarChannel.invokeMethod<bool>(
            'isPointerOverTaskbarUi',
          ) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  void _cancelPendingBlurHide() {
    _blurHideTimer?.cancel();
    _blurHideTimer = null;
  }

  @override
  void onClose() {
    _nativeShowGuard?.cancel();
    _cancelPendingBlurHide();
    windowManager.removeListener(this);
    super.onClose();
  }
}

Display _displayContaining(Offset point, List<Display> displays) {
  for (final display in displays) {
    final origin = display.visiblePosition ?? Offset.zero;
    final size = display.visibleSize ?? display.size;
    if ((origin & size).contains(point)) {
      return display;
    }
  }
  return displays.first;
}
