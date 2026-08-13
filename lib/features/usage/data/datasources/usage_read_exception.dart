import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

class UsageReadException implements Exception {
  const UsageReadException(this.issue);

  final UsageConnectionIssue issue;
}
