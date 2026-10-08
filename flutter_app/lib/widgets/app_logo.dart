import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.calendar_month_rounded, size: size * 0.72, color: Colors.white),
            Positioned(
              right: size * 0.04,
              bottom: size * 0.06,
              child: Icon(Icons.auto_awesome_rounded, size: size * 0.34, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
