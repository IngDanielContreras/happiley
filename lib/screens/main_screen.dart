import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'explore_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'article_detail_screen.dart';
import 'publish_article_screen.dart';
import '../models/article.dart';
import '../widgets/bottom_navigation.dart';
import 'home_screen.dart';
import '../services/session_manager.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  final Database? database;

  const MainScreen({
    super.key,
    this.database,
    this.initialIndex = 0,
  });

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  late int currentIndex;
  late PageController pageController;

  Article? selectedArticle;
  List<Article> availableArticles = [];

  int exploreKeyCounter = 0;

  @override
  void initState() {
    super.initState();

    currentIndex = widget.initialIndex.clamp(0, 3);

    pageController = PageController(
      initialPage: currentIndex,
    );
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  // Cambio de la pestaña activa en la barra de navegacion inferior
  void changeTab(int index) {
    if (index < 0 || index > 3) return;

    setState(() {
      currentIndex = index;
      selectedArticle = null;
    });

    if (pageController.hasClients &&
        pageController.page?.round() != index) {
      pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      currentIndex = index;

      if (index != 1) {
        selectedArticle = null;
      }
    });
  }

  // Seleccion de un articulo especifico para visualizar sus detalles
  void selectArticle(
      Article article, {
        List<Article>? articlesList,
      }) {
    setState(() {
      selectedArticle = article;

      if (articlesList != null) {
        availableArticles = List<Article>.from(articlesList);
      }

      currentIndex = 1;
    });

    if (pageController.hasClients &&
        pageController.page?.round() != 1) {
      pageController.jumpToPage(1);
    }
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
    });

    changeTab(2);
  }

  // Gestion posterior a un inicio de sesion exitoso
  void _handleLoginSuccess(String userCode) {
    changeTab(3);
  }

  // Proceso de cierre de sesion activa del usuario
  Future<void> onLogout() async {
    await SessionManager.clearSession();

    if (!mounted) return;

    changeTab(3);
  }

  // Incremento del contador para forzar la recarga de explore screen y redireccion a ExploreScreen
  void refreshExploreScreen() {
    setState(() {
      exploreKeyCounter++;
      selectedArticle = null;
    });

    changeTab(1);
  }

  void _handlePopInvoked(bool didPop, dynamic result) {
    if (didPop) return;

    if (selectedArticle != null) {
      clearSelectedArticle();
      return;
    }

    if (currentIndex == 4) {
      changeTab(3);
      return;
    }

    if (currentIndex != 0) {
      changeTab(0);
      return;
    }

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Alternancia dinamica entre la interfaz de exploracion y los detalles del carrito
    final Widget exploreOrDetailWidget = selectedArticle != null
        ? ArticleDetailScreen(
      key: const ValueKey('article_detail_screen'),
      article: selectedArticle!,
      articlesList: availableArticles,
      onBack: clearSelectedArticle,
      onBuyNow: buyNowAndGoToCart,
      onArticleChanged: (newArticle) {
        setState(() {
          selectedArticle = newArticle;
        });
      },
    )
        : ExploreScreen(
      key: ValueKey('explore_screen_$exploreKeyCounter'),
      onCartPressed: () {
        changeTab(2);
      },
      onHomePressed: () {
        changeTab(0);
      },
      onArticleSelected: (article, articlesList) {
        selectArticle(
          article,
          articlesList: articlesList,
        );
      },
    );

    final bool canSystemPop = currentIndex == 0 &&
        selectedArticle == null &&
        !Navigator.canPop(context);

    return PopScope<Object?>(
      canPop: canSystemPop,
      onPopInvokedWithResult: _handlePopInvoked,
      child: ValueListenableBuilder<String?>(
        valueListenable: SessionManager.activeUserCode,
        builder: (context, userCode, child) {
          // Renderizado condicional del perfil de usuario o el formulario de inicio de sesion
          final Widget profileOrLoginWidget = userCode != null
              ? ProfileScreen(
            key: ValueKey('user_profile_$userCode'),
            userCode: userCode,
            onLogout: onLogout,
            onPublishArticle: () {
              setState(() {
                currentIndex = 4;
              });
            },
          )
              : LoginScreen(
            key: const Key('user_login_screen'),
            onLoginSuccess: _handleLoginSuccess,
          );

          return Scaffold(
            body: currentIndex == 4
                ? PublishArticleScreen(
              database: widget.database,
              onBack: () {
                changeTab(3);
              },
              onArticlePublished: refreshExploreScreen,
            )
                : PageView(
              controller: pageController,
              onPageChanged: _onPageChanged,
              physics: selectedArticle != null
                  ? const NeverScrollableScrollPhysics()
                  : const ClampingScrollPhysics(),
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
            bottomNavigationBar: currentIndex < 4
                ? BottomNavigation(
              selectedIndex: currentIndex,
              onIndexChanged: (index) {
                changeTab(index);
              },
            )
                : null,
          );
        },
      ),
    );
  }
}