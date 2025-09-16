// lib/background_design.dart
import 'package:flutter/material.dart';

class BackgroundDesign extends StatelessWidget {
  const BackgroundDesign({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // White background
        Container(color: Colors.white),

        // Blue circle (top-left)
        Positioned(
          top: -80,
          left: -30,
          child: Container(
            width: 377,
            height: 358,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.blue.withOpacity(0.4),
                  Colors.white.withOpacity(0),
                ],
                radius: 0.6,
              ),
            ),
          ),
        ),

        // Green circle (top-right)
        Positioned(
          top: -20,
          right: -10,
          child: Container(
            width: 377,
            height: 358,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.green.withOpacity(0.4),
                  Colors.green.withOpacity(0),
                ],
                radius: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
