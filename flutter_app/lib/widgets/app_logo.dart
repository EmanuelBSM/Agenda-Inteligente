import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.calendar_month_rounded, size: size * 0.72, color: const Color(0xFF444444)),
          Positioned(
            right: size * 0.04,
            bottom: size * 0.06,
            child: Icon(Icons.auto_awesome_rounded, size: size * 0.34, color: const Color(0xFF444444)),
          ),
        ],
      ),
    );
  }
}
