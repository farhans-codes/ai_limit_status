import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

class AppWindowService extends GetxService with WindowListener {
  final Completer<void> _ready = Completer<void>();
  bool _isQuitting = false;
  bool _isShowing = false;
  bool _isModalOpen = false;
  Timer? _nativeShowGuard;

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
  }

  Future<void> showPopover() async {
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
      await windowManager.show();
      await windowManager.focus();
      await Future<void>.delayed(const Duration(milliseconds: 250));
    } finally {
      _isShowing = false;
    }
  }

  Future<void> togglePopover() async {
    if (await windowManager.isVisible()) {
      await windowManager.hide();
      return;
    }
    await showPopover();
  }

  void prepareForNativeShow() {
    _nativeShowGuard?.cancel();
    _isShowing = true;
    _nativeShowGuard = Timer(const Duration(milliseconds: 500), () {
      _isShowing = false;
    });
  }

  Future<void> quit() async {
    _isQuitting = true;
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
    if (!_isQuitting &&
        !_isShowing &&
        !_isModalOpen &&
        await windowManager.isVisible()) {
      await windowManager.hide();
    }
  }

  @override
  void onClose() {
    _nativeShowGuard?.cancel();
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
