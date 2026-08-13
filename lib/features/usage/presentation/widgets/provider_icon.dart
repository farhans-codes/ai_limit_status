import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

class ProviderIcon extends StatelessWidget {
  const ProviderIcon({required this.provider, this.size = 26, super.key});

  final UsageProvider provider;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isCodex = provider == UsageProvider.codex;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isCodex ? const Color(0xFF15171A) : const Color(0xFFC66B45),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.2),
        child: SvgPicture.asset(
          isCodex ? 'assets/icons/codex.svg' : 'assets/icons/claude.svg',
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      ),
    );
  }
}
