import 'package:flutter/material.dart';

/// In-app brand emblem — always the **transparent** asset.
/// Do not use [AppBrandLogo] for the Android/iOS launcher icon.
class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    this.size = 120,
    this.opacity,
  });

  static const String transparentAsset = 'assets/icon/app_icon_logo.png';

  final double size;
  final double? opacity;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      transparentAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Icon(
        Icons.restaurant_rounded,
        size: size * 0.55,
        color: const Color(0xFF1A5D1A),
      ),
    );
    if (opacity == null) return image;
    return Opacity(opacity: opacity!, child: image);
  }
}
