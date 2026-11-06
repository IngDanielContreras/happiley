import 'package:flutter/material.dart';

// Gestor de estado global para el tema de la aplicacion (Claro / Oscuro)
class ThemeManager {
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;

  ThemeManager._internal();

  final ValueNotifier<ThemeMode> themeModeNotifier =
  ValueNotifier<ThemeMode>(ThemeMode.light);

  bool get isDarkMode => themeModeNotifier.value == ThemeMode.dark;

  // Alternancia dinamica entre tema claro y tema oscuro
  void toggleTheme() {
    if (isDarkMode) {
      themeModeNotifier.value = ThemeMode.light;
    } else {
      themeModeNotifier.value = ThemeMode.dark;
    }
  }

  // Establecimiento directo del modo de tema seleccionado
  void setTheme(ThemeMode mode) {
    themeModeNotifier.value = mode;
  }
}