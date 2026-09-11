import 'package:flutter/material.dart';
import 'explore_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import '../widgets/bottom_navigation.dart';
import 'home_screen.dart';

// Pantalla principal - Navegacion usando pestañas
class MainScreen extends StatefulWidget {
  final int initialIndex;
  final int? userId;

  const MainScreen({
    super.key,
    this.initialIndex = 0,
    this.userId,
  });

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  late int currentIndex;
  int? authenticatedUserId;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    authenticatedUserId = widget.userId;
  }

  // Cambio de pestaña
  void changeTab(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  // Registro del inicio de sesion exitoso
  void onLoginSuccess(int userId) {
    setState(() {
      authenticatedUserId = userId;
      currentIndex = 3;
    });
  }

  // Cierre de sesion y regreso al login
  void onLogout() {
    setState(() {
      authenticatedUserId = null;
      currentIndex = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Definicion dinamica del perfil
    final Widget profileOrLoginWidget = authenticatedUserId != null
        ? ProfileScreen(
      key: ValueKey('user_profile_$authenticatedUserId'),
      userId: authenticatedUserId!,
      onLogout: onLogout,
    )
        : LoginScreen(
      key: const ValueKey('user_login_screen'),
      onLoginSuccess: onLoginSuccess,
    );

    return Scaffold(
      // Almacenamiento de interfaces
      body: IndexedStack(
        index: currentIndex,
        children: [
          const HomeScreen(),
          ExploreScreen(
            onCartPressed: () {
              changeTab(2);
            },
          ),
          const CartScreen(),
          profileOrLoginWidget,
        ],
      ),

      // Barra de navegacion inferior
      bottomNavigationBar: BottomNavigation(
        selectedIndex: currentIndex,
        onIndexChanged: (index) {
          changeTab(index);
        },
      ),
    );
  }
}