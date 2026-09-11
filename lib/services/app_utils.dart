import 'package:flutter/material.dart';

class AppUtils {
  // Formateo de precio en pesos colombianos COP
  static String formatPrice(double price) {
    return '\$${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
          (match) => '${match.group(1)}.',
    )} COP';
  }

  // Mostrar un mensaje rapido en pantalla
  static void showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}