import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:ai_limit_status/core/platform/app_instance_guard.dart';
import 'package:ai_limit_status/core/platform/app_window_service.dart';
import 'package:ai_limit_status/core/theme/app_theme.dart';
import 'package:ai_limit_status/features/usage/presentation/bindings/usage_binding.dart';
import 'package:ai_limit_status/features/usage/presentation/pages/usage_page.dart';
import 'package:ai_limit_status/l10n/app_localizations.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!await AppInstanceGuard.acquire()) {
    exit(0);
  }
  await windowManager.ensureInitialized();

  final windowService = AppWindowService();
  await windowService.initialize();
  Get.put<AppWindowService>(windowService, permanent: true);

  const windowOptions = WindowOptions(
    size: Size(380, 520),
    minimumSize: Size(380, 520),
    maximumSize: Size(380, 520),
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    alwaysOnTop: true,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  runApp(const LimitStatusApp());

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setSize(windowOptions.size!);
    await windowManager.setMinimumSize(windowOptions.minimumSize!);
    await windowManager.setMaximumSize(windowOptions.maximumSize!);
    await windowManager.setResizable(false);
    await windowManager.setMovable(false);
    await windowManager.setMinimizable(false);
    await windowManager.setMaximizable(false);
    await windowManager.setHasShadow(true);
    if (Platform.isMacOS) {
      await windowManager.setVisibleOnAllWorkspaces(
        true,
        visibleOnFullScreen: true,
      );
    }
    await windowManager.hide();
  });
}

class LimitStatusApp extends StatelessWidget {
  const LimitStatusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      initialBinding: UsageBinding(),
      home: const UsagePage(),
    );
  }
}
