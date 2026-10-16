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

  // Cambio de la pestaña activa en la barra de navegacion inferior
  void changeTab(int index) {
    setState(() {
      currentIndex = index;
      selectedArticle = null;
    });
  }

  // Seleccion de un articulo especifico para visualizar sus detalles
  void selectArticle(Article article) {
    setState(() {
      selectedArticle = article;
      currentIndex = 1;
    });
  }

  // Limpieza y cierre de la vista de detalles del articulo
  void clearSelectedArticle() {
    setState(() {
      selectedArticle = null;
    });
  }

  // Transicion directa hacia la pagina del carrito de compras
  void buyNowAndGoToCart() {
    setState(() {
      selectedArticle = null;
      currentIndex = 2;
    });
  }

  // Gestion posterior a un inicio de sesión exitoso
  void _handleLoginSuccess(String userCode) {
    setState(() {
      currentIndex = 3;
    });
  }

  // Proceso de cierre de sesion activa del usuario
  Future<void> onLogout() async {
    await SessionManager.clearSession();

    if (!mounted) return;

    setState(() {
      currentIndex = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Alternancia dinamica entre la interfaz de exploracion y los detalles del carrito
    final Widget exploreOrDetailWidget = selectedArticle != null
        ? ArticleDetailScreen(
      key: ValueKey('detail_${selectedArticle!.id}'),
      article: selectedArticle!,
      onBack: clearSelectedArticle,
      onBuyNow: buyNowAndGoToCart,
    )
        : ExploreScreen(
      key: const ValueKey('explore_screen'),
      onCartPressed: () {
        changeTab(2);
      },
      onArticleSelected: selectArticle,
    );

    return ValueListenableBuilder<String?>(
      valueListenable: SessionManager.activeUserCode,
      builder: (context, userCode, child) {
        // Renderizado condicional del perfil de usuario o el formulario de inicio de sesion
        final Widget profileOrLoginWidget = userCode != null
            ? ProfileScreen(
          key: ValueKey('user_profile_$userCode'),
          userCode: userCode,
          onLogout: onLogout,
        )
            : LoginScreen(
          key: const Key('user_login_screen'),
          onLoginSuccess: _handleLoginSuccess,
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
              const CartScreen(
                key: ValueKey('cart_screen'),
              ),
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