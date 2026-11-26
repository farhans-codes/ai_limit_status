import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';
import 'package:ai_limit_status/features/usage/presentation/provider_definition.dart';

class ProviderIcon extends StatelessWidget {
  const ProviderIcon({required this.provider, this.size = 26, super.key});

  final UsageProvider provider;
  final double size;

  @override
  Widget build(BuildContext context) {
    final definition = provider.definition;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: definition.iconBackground,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.2),
        child: SvgPicture.asset(
          definition.iconAsset,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      ),
    );
  }
}
