abstract interface class UsageWarningRepository {
  Future<void> initialize(String appName);

  Future<bool> showOnce({
    required String identifier,
    required String title,
    required String body,
  });
}
