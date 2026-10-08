import 'package:flutter/material.dart';

// Importacion dependiendo de la interfaz a probar
import 'profile_screen.dart';

void main() {
  runApp(const DynamicSandboxApp());
}

class DynamicSandboxApp extends StatelessWidget {
  const DynamicSandboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Modo Prueba de Pantalla',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5548F5),
        ),
      ),
      home: Scaffold(
        body: SafeArea(
          // Interfaz a probar
          child: ProfileScreen(
            userCode: 'VUR001',
            onLogout: () {},
          ),
        ),
      ),
    );
  }
}