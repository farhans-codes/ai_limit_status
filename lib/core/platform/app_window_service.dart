import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';
import 'package:ai_limit_status/core/platform/windows_diagnostic_log.dart';

class AppWindowService extends GetxService with WindowListener {
  static const _windowsBlurGracePeriod = Duration(milliseconds: 150);

  final Completer<void> _ready = Completer<void>();
  bool _isQuitting = false;
  bool _isShowing = false;
  bool _isModalOpen = false;
  Timer? _nativeShowGuard;
  Timer? _blurHideTimer;

  Future<void> get whenReady => _ready.future;

  Future<void> initialize() async {
    WindowsDiagnosticLog.write('window.initialize start');
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
    WindowsDiagnosticLog.write('window.initialize complete');
  }

  void markReady() {
    if (!_ready.isCompleted) {
      _ready.complete();
    }
  }

  void setModalOpen(bool isOpen) {
    _isModalOpen = isOpen;
    WindowsDiagnosticLog.write('window.modal isOpen=$isOpen');
    if (isOpen) {
      _cancelPendingBlurHide();
    }
  }

  Future<void> showPopover() async {
    WindowsDiagnosticLog.write(
      'window.show requested isShowing=$_isShowing modal=$_isModalOpen',
    );
    _cancelPendingBlurHide();
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

    _isShowing = true;
    try {
      await windowManager.setPosition(position);
      WindowsDiagnosticLog.write('window.show position-set');
      await windowManager.show();
      WindowsDiagnosticLog.write('window.show visible');
      await windowManager.focus();
      WindowsDiagnosticLog.write('window.show focused');
      await Future<void>.delayed(const Duration(milliseconds: 250));
    } finally {
      _isShowing = false;
      WindowsDiagnosticLog.write('window.show guard-cleared');
    }
  }

  Future<void> togglePopover() async {
    WindowsDiagnosticLog.write('window.toggle requested');
    _cancelPendingBlurHide();
    final wasVisible = await windowManager.isVisible();
    WindowsDiagnosticLog.write('window.toggle observedVisible=$wasVisible');
    if (wasVisible) {
      await windowManager.hide();
      WindowsDiagnosticLog.write('window.toggle action=hide complete');
      return;
    }
    WindowsDiagnosticLog.write('window.toggle action=show');
    await showPopover();
  }

  void prepareForNativeShow() {
    WindowsDiagnosticLog.write('window.native-show guard-start');
    _nativeShowGuard?.cancel();
    _isShowing = true;
    _nativeShowGuard = Timer(const Duration(milliseconds: 500), () {
      _isShowing = false;
      WindowsDiagnosticLog.write('window.native-show guard-cleared');
    });
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
    WindowsDiagnosticLog.write(
      'window.blur quitting=$_isQuitting showing=$_isShowing '
      'modal=$_isModalOpen',
    );
    if (_isQuitting || _isShowing || _isModalOpen) {
      WindowsDiagnosticLog.write('window.blur ignored');
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
    WindowsDiagnosticLog.write('window.focus');
    _cancelPendingBlurHide();
  }

  void _scheduleWindowsBlurHide() {
    _cancelPendingBlurHide();
    WindowsDiagnosticLog.write('window.blur-hide scheduled delayMs=150');
    _blurHideTimer = Timer(_windowsBlurGracePeriod, () async {
      _blurHideTimer = null;
      final isVisible = await windowManager.isVisible();
      WindowsDiagnosticLog.write(
        'window.blur-hide fired quitting=$_isQuitting showing=$_isShowing '
        'modal=$_isModalOpen visible=$isVisible',
      );
      if (!_isQuitting && !_isShowing && !_isModalOpen && isVisible) {
        await windowManager.hide();
        WindowsDiagnosticLog.write('window.blur-hide action=hide complete');
      } else {
        WindowsDiagnosticLog.write('window.blur-hide action=skip');
      }
    });
  }

  void _cancelPendingBlurHide() {
    if (_blurHideTimer != null) {
      WindowsDiagnosticLog.write('window.blur-hide cancelled');
    }
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
