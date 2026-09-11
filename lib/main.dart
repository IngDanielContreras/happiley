import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/cart_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carga de articulos persistidos
  await CartManager.loadSavedCart();

  runApp(const HappileyApp());
}

class HappileyApp extends StatelessWidget {
  const HappileyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Happiley',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5548F5),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
