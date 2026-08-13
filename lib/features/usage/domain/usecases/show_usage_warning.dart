import 'package:ai_limit_status/features/usage/domain/repositories/usage_warning_repository.dart';

class ShowUsageWarning {
  const ShowUsageWarning(this._repository);

  final UsageWarningRepository _repository;

  Future<void> initialize(String appName) => _repository.initialize(appName);

  Future<bool> call({
    required String identifier,
    required String title,
    required String body,
  }) {
    return _repository.showOnce(
      identifier: identifier,
      title: title,
      body: body,
    );
  }
}
