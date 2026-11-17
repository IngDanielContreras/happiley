import 'package:flutter/material.dart';
import 'services/theme_manager.dart';
import 'services/session_manager.dart';
import 'services/music_manager.dart';
import 'services/system_sound_manager.dart';
import 'services/multimedia_manager.dart';
import 'services/notification_service.dart';
import 'screens/main_screen.dart';
import 'services/cart_manager.dart';
import 'services/saved_items_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializacion de gestores globales de audio y ciclo de vida
  MusicManager();
  SystemSoundManager();
  MultimediaManager();

  await Future.wait([
    SessionManager.loadSavedSession(),
    CartManager.loadSavedCart(),
  ]);

  // Inicializacion de la lista de deseos asociada a la sesion activa
  await SavedItemsManager.initialize();

  // Inicializacion del servicio centralizado de notificaciones
  await NotificationService().initialize();

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
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFFE6E8EF),
              surfaceTintColor: Colors.transparent,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              titleTextStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF181B24),
              ),
              contentTextStyle: TextStyle(
                fontSize: 14,
                color: Color(0xFF373D4D),
              ),
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
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF252834),
              surfaceTintColor: Colors.transparent,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              titleTextStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF1F3F9),
              ),
              contentTextStyle: TextStyle(
                fontSize: 14,
                color: Color(0xFFC7CDDC),
              ),
            ),
          ),

          home: const MainScreen(),
        );
      },
    );
  }
}