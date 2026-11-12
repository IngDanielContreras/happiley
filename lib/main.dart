import 'package:flutter/material.dart';
import 'services/theme_manager.dart';
import 'services/session_manager.dart';
import 'services/music_manager.dart';
import 'services/system_sound_manager.dart';
import 'screens/main_screen.dart';
import 'services/cart_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializacion de gestores globales de audio y ciclo de vida
  MusicManager();
  SystemSoundManager();

  await Future.wait([
    SessionManager.loadSavedSession(),
    CartManager.loadSavedCart(),
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager();

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeManager.themeModeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Happiley',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,

          // Definicion del tema claro principal de la aplicacion
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            primaryColor: const Color(0xFF5548F5),
            scaffoldBackgroundColor: const Color(0xFFF8F9FA),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF5548F5),
              brightness: Brightness.light,
            ),
          ),

          // Definicion del tema oscuro para soporte en toda la interfaz
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF5548F5),
            scaffoldBackgroundColor: const Color(0xFF121212),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF5548F5),
              brightness: Brightness.dark,
            ),
          ),

          home: const MainScreen(),
        );
      },
    );
  }
}