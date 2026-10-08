import 'package:flutter/material.dart';
import 'explore_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'article_detail_screen.dart';
import '../models/article.dart';
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
  Article? selectedArticle;

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
      selectedArticle = null; // Limpia la selección al cambiar de pestaña
    });
  }

  // Selección de un artículo para ver su detalle
  void selectArticle(Article article) {
    setState(() {
      selectedArticle = article;
      currentIndex = 1;
    });
  }

  // Regreso a la lista de exploración
  void clearSelectedArticle() {
    setState(() {
      selectedArticle = null;
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

    // Vista dinámica para la pestaña de Exploración
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

    return Scaffold(
      // Almacenamiento de interfaces
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