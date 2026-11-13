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
import '../widgets/alert_message.dart';
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
  static MainScreenState? of(BuildContext context) {
    return context.findAncestorStateOfType<MainScreenState>();
  }

  late int currentIndex;
  late PageController pageController;

  Article? selectedArticle;
  List<Article> availableArticles = [];

  int exploreKeyCounter = 0;
  bool _pendingCartRedirect = false;
  bool _isAuthPromptOpen = false;
  DateTime? _lastAuthPromptTime;

  @override
  void initState() {
    super.initState();

    // Validacion inicial de acceso al carrito segun estado de sesion
    final requestedIndex = widget.initialIndex.clamp(0, 3);

    if (requestedIndex == 2 && !SessionManager.isLoggedIn) {
      currentIndex = 3;
      _pendingCartRedirect = true;
    } else {
      currentIndex = requestedIndex;
    }

    pageController = PageController(
      initialPage: currentIndex,
    );
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  // Despliegue de alerta de autenticacion requerida para acceder al carrito
  void promptAuthentication({bool redirectToCartAfterLogin = true}) {
    if (_isAuthPromptOpen || !mounted) return;

    final now = DateTime.now();

    if (_lastAuthPromptTime != null &&
        now.difference(_lastAuthPromptTime!) <
            const Duration(milliseconds: 600)) {
      return;
    }

    _isAuthPromptOpen = true;
    _lastAuthPromptTime = now;

    AlertMessage.show(
      context: context,
      title: 'Inicio de Sesión Requerido',
      message: 'Debes iniciar sesión para realizar esta acción.',
      confirmText: 'Iniciar Sesión',
      cancelText: 'Cancelar',
      isConfirmDefault: true,
      onConfirm: () {
        _isAuthPromptOpen = false;
        _lastAuthPromptTime = DateTime.now();

        if (redirectToCartAfterLogin) {
          _pendingCartRedirect = true;
        }

        changeTab(3);
      },
      onCancel: () {
        _isAuthPromptOpen = false;
        _lastAuthPromptTime = DateTime.now();
      },
    ).then((_) {
      _isAuthPromptOpen = false;
    });
  }

  // Cambio de la pestana activa en la barra de navegacion inferior
  void changeTab(int index) {
    if (index < 0 || index > 3) return;

    // Bloqueo de navegacion directa al carrito sin sesion activa
    if (index == 2 && !SessionManager.isLoggedIn) {
      if (pageController.hasClients &&
          pageController.page?.round() != currentIndex) {
        pageController.jumpToPage(currentIndex);
      }

      promptAuthentication(redirectToCartAfterLogin: true);
      return;
    }

    setState(() {
      currentIndex = index;
      selectedArticle = null;
    });

    if (pageController.hasClients && pageController.page?.round() != index) {
      pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // Control de cambio de pagina mediante deslizamiento horizontal
  void _onPageChanged(int index) {
    if (index == 2 && !SessionManager.isLoggedIn) {
      if (pageController.hasClients) {
        pageController.jumpToPage(currentIndex);
      }

      promptAuthentication(redirectToCartAfterLogin: true);
      return;
    }

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

    if (pageController.hasClients && pageController.page?.round() != 1) {
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
    if (!SessionManager.isLoggedIn) {
      promptAuthentication(redirectToCartAfterLogin: true);
      return;
    }

    setState(() {
      selectedArticle = null;
    });

    changeTab(2);
  }

  // Gestion posterior a un inicio de sesion exitoso
  void _handleLoginSuccess(String userCode) {
    if (_pendingCartRedirect) {
      _pendingCartRedirect = false;
      changeTab(2);
    } else {
      changeTab(3);
    }
  }

  // Proceso de cierre de sesion activa del usuario
  Future<void> onLogout() async {
    _pendingCartRedirect = false;
    await SessionManager.clearSession();

    if (!mounted) return;

    changeTab(3);
  }

  // Incremento del contador para forzar la recarga de explore screen
  void refreshExploreScreen() {
    setState(() {
      exploreKeyCounter++;
      selectedArticle = null;
      currentIndex = 1;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !pageController.hasClients) return;

      pageController.jumpToPage(1);
    });
  }

  // Retorno al perfil del usuario desde la pantalla de publicacion
  void returnToProfile() {
    if (!mounted || currentIndex != 4) return;

    setState(() {
      currentIndex = 3;
      selectedArticle = null;
    });
  }

  // Gestion del gesto de retroceso del sistema Android
  void _handlePopInvoked(bool didPop, dynamic result) {
    if (didPop) return;

    if (selectedArticle != null) {
      clearSelectedArticle();
      return;
    }

    if (currentIndex == 4) {
      returnToProfile();
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
          final bool isAuthenticated = userCode != null;

          // Renderizado condicional del perfil de usuario o inicio de sesion
          final Widget profileOrLoginWidget = isAuthenticated
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

          // Renderizado protegido del carrito segun estado de autenticacion
          final Widget protectedCartWidget = isAuthenticated
              ? CartScreen(
            key: const ValueKey('cart_screen'),
            isActive: currentIndex == 2,
          )
              : CartScreen(
            key: const ValueKey('cart_screen_restricted'),
            isActive: currentIndex == 2,
            onRequestLogin: () {
              _pendingCartRedirect = true;
              changeTab(3);
            },
          );

          return Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                PageView(
                  controller: pageController,
                  onPageChanged: (index) {
                    // Prevenir disparar la redireccion/prompt de autenticacion al deslizar libremente hacia el carrito sin estar logueado
                    if (index == 2 && !SessionManager.isLoggedIn) {
                      if (pageController.hasClients) {
                        pageController.jumpToPage(currentIndex);
                      }
                      return;
                    }
                    _onPageChanged(index);
                  },
                  physics: selectedArticle != null || !isAuthenticated
                      ? const NeverScrollableScrollPhysics()
                      : const ClampingScrollPhysics(),
                  children: [
                    HomeScreen(
                      onExplore: () {
                        changeTab(1);
                      },
                    ),
                    exploreOrDetailWidget,
                    protectedCartWidget,
                    profileOrLoginWidget,
                  ],
                ),
                if (currentIndex == 4)
                  Positioned.fill(
                    child: PublishArticleScreen(
                      database: widget.database,
                      onBack: returnToProfile,
                      onArticlePublished: refreshExploreScreen,
                    ),
                  ),
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