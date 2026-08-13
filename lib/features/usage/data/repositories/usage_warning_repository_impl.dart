import 'dart:collection';

import 'package:ai_limit_status/core/platform/desktop_notification_service.dart';
import 'package:ai_limit_status/features/usage/data/datasources/usage_warning_state_store.dart';
import 'package:ai_limit_status/features/usage/domain/repositories/usage_warning_repository.dart';

class UsageWarningRepositoryImpl implements UsageWarningRepository {
  UsageWarningRepositoryImpl(this._notificationService, this._stateStore);

  final DesktopNotificationService _notificationService;
  final UsageWarningStateStore _stateStore;

  LinkedHashSet<String>? _shownIdentifiers;

  @override
  Future<void> initialize(String appName) async {
    await _notificationService.initialize(appName);
    _shownIdentifiers ??= await _stateStore.readIdentifiers();
  }

  @override
  Future<bool> showOnce({
    required String identifier,
    required String title,
    required String body,
  }) async {
    final identifiers = _shownIdentifiers ??= await _stateStore
        .readIdentifiers();
    if (identifiers.contains(identifier)) {
      return false;
    }

    final wasShown = await _notificationService.show(title: title, body: body);
    if (!wasShown) {
      return false;
    }
    identifiers.add(identifier);
    try {
      await _stateStore.writeIdentifiers(identifiers);
    } on Object {
      // The in-memory identifier still prevents repeated notifications during
      // this run if the operating system rejects persistence.
    }
    return true;
  }
}
