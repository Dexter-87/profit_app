import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF151922);
  static const card = Color(0xFF11161F);
  static const stroke = Color(0xFF232A36);

  static const primary = Color(0xFF4DA3FF);
  static const primaryDark = Color(0xFF2D7DFF);

  static const textMain = Colors.white;
  static const textSecondary = Colors.white70;
  static const success = Color(0xFF59D98E);
  static const danger = Color(0xFFFF6B6B);

  static const LinearGradient mainGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF4DA3FF),
      Color(0xFF2D7DFF),
    ],
  );
}
