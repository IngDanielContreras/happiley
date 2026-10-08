import 'package:flutter/material.dart';
import '../services/session_manager.dart';
import '../services/cart_manager.dart';
import 'screens/main_screen.dart';

void main() async {
  // Asegura la inicializacion de los bindings de Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Carga previa de la sesion guardada en la base de datos
  await SessionManager.loadSavedSession();
  await CartManager.loadSavedCart();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Happiley',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5548F5),
        ),
      ),
      home: const MainScreen(),
    );
  }
}