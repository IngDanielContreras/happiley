import 'package:flutter/material.dart';
import 'explore_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'article_detail_screen.dart';
import '../models/article.dart';
import '../widgets/bottom_navigation.dart';
import 'home_screen.dart';
import '../services/session_manager.dart';

// Pantalla principal con gestion de navegacion y reactividad de sesion
class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  late int currentIndex;
  Article? selectedArticle;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
  }

  // Cambio de pestana activa
  void changeTab(int index) {
    setState(() {
      currentIndex = index;
      selectedArticle = null;
    });
  }

  // Seleccion de un articulo para ver en detalle
  void selectArticle(Article article) {
    setState(() {
      selectedArticle = article;
      currentIndex = 1;
    });
  }

  // Limpieza del articulo seleccionado
  void clearSelectedArticle() {
    setState(() {
      selectedArticle = null;
    });
  }

  // Notificacion de inicio de sesion
  void onLoginSuccess(dynamic userCode) {
    setState(() {
      currentIndex = 3;
    });
  }

  // Cierre de sesion reactivo
  Future<void> onLogout() async {
    await SessionManager.clearSession();
    setState(() {
      currentIndex = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Vista dinamica para la pestana de exploracion
    final Widget exploreOrDetailWidget = selectedArticle != null
        ? ArticleDetailScreen(
      article: selectedArticle!,
      onBack: clearSelectedArticle,
    )
        : ExploreScreen(
      onCartPressed: () {
        changeTab(2);
      },
      onArticleSelected: selectArticle,
    );

    return ValueListenableBuilder<String?>(
      valueListenable: SessionManager.activeUserCode,
      builder: (context, userCode, child) {
        // Seleccion automatica entre Perfil y Formulario de Login
        final Widget profileOrLoginWidget = userCode != null
            ? ProfileScreen(
          key: ValueKey('user_profile_$userCode'),
          userCode: userCode,
          onLogout: onLogout,
        )
            : LoginScreen(
          key: const ValueKey('user_login_screen'),
          onLoginSuccess: onLoginSuccess,
        );

        return Scaffold(
          body: IndexedStack(
            index: currentIndex,
            children: [
              HomeScreen(
                onExplore: () {
                  changeTab(1);
                },
              ),
              exploreOrDetailWidget,
              const CartScreen(),
              profileOrLoginWidget,
            ],
          ),
          bottomNavigationBar: BottomNavigation(
            selectedIndex: currentIndex,
            onIndexChanged: (index) {
              changeTab(index);
            },
          ),
        );
      },
    );
  }
}