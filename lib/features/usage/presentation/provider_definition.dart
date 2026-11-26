import 'package:ai_limit_status/core/constants/app_strings.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';
import 'package:flutter/material.dart';

/// How one provider is presented. Adding a provider means adding a
/// [UsageProvider] value, its definition here, and its reader in
/// `LiveUsageDataSource`.
class ProviderDefinition {
  const ProviderDefinition({
    required this.name,
    required this.iconAsset,
    required this.iconBackground,
    required this.accent,
    required this.settingsIcon,
    required this.hasCliSetup,
  });

  final String name;
  final String iconAsset;
  final Color iconBackground;
  final Color accent;
  final IconData settingsIcon;

  /// Whether the provider is set up by installing and signing in to a CLI.
  final bool hasCliSetup;
}

extension UsageProviderDefinition on UsageProvider {
  ProviderDefinition get definition {
    final strings = AppStrings.instance;
    return switch (this) {
      UsageProvider.codex => ProviderDefinition(
        name: strings.providerCodex,
        iconAsset: 'assets/icons/codex.svg',
        iconBackground: const Color(0xFF15171A),
        accent: const Color(0xFF42C7B2),
        settingsIcon: Icons.code_rounded,
        hasCliSetup: true,
      ),
      UsageProvider.claude => ProviderDefinition(
        name: strings.providerClaude,
        iconAsset: 'assets/icons/claude.svg',
        iconBackground: const Color(0xFFC66B45),
        accent: const Color(0xFFE7835B),
        settingsIcon: Icons.auto_awesome_rounded,
        hasCliSetup: true,
      ),
      UsageProvider.antigravity => ProviderDefinition(
        name: strings.providerAntigravity,
        iconAsset: 'assets/icons/antigravity.svg',
        iconBackground: const Color(0xFF1F2A44),
        accent: const Color(0xFF6C9BFF),
        settingsIcon: Icons.rocket_launch_rounded,
        hasCliSetup: false,
      ),
    };
  }
}
