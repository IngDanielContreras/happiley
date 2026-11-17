import 'dart:io';
import 'package:flutter/material.dart';
import '../database/article_service.dart';
import '../database/persistence_service.dart';
import '../models/article.dart';
import '../models/user.dart';
import '../services/app_utils.dart';
import '../services/cart_manager.dart';
import '../services/saved_items_manager.dart';
import '../services/session_manager.dart';
import '../services/system_sound_manager.dart';
import '../widgets/alert_message.dart';
import '../widgets/loading_dialog.dart';
import 'article_detail_screen.dart';
import 'login_screen.dart';
import 'publish_article_screen.dart';

class MyItemsScreen extends StatefulWidget {
  final User? user;

  const MyItemsScreen({
    super.key,
    this.user,
  });

  @override
  State<MyItemsScreen> createState() => _MyItemsScreenState();
}

class _MyItemsScreenState extends State<MyItemsScreen> {
  final ArticleService _articleService = ArticleService();
  final PersistenceService _persistenceService = PersistenceService();

  List<Article> _sellerArticles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    SessionManager.activeUserCode.addListener(_handleSessionChanged);
    _loadSellerArticles();
  }

  @override
  void dispose() {
    SessionManager.activeUserCode.removeListener(_handleSessionChanged);
    super.dispose();
  }

  // Recarga automatica al cambiar o cerrar la sesion activa
  void _handleSessionChanged() {
    if (!mounted) return;
    _loadSellerArticles();
  }

  // Validacion del rol autorizado de vendedor o administrador
  bool _hasSellerPermissions() {
    final String? userCode = SessionManager.activeUserCode.value;
    if (userCode == null || userCode.trim().isEmpty) {
      return false;
    }

    final String normalizedCode = userCode.trim().toUpperCase();
    final User? currentUser = widget.user;
    final String cleanRole =
    (currentUser != null &&
        currentUser.code.trim().toUpperCase() == normalizedCode)
        ? currentUser.role.toLowerCase().trim()
        : '';

    final bool isSeller = cleanRole == 'vendedor' ||
        cleanRole == 'seller' ||
        normalizedCode.startsWith('SUR');
    final bool isAdmin = cleanRole == 'administrador' ||
        cleanRole == 'admin' ||
        normalizedCode.startsWith('AUR');

    return isSeller || isAdmin;
  }

  // Carga exclusiva de los articulos publicados por el vendedor autenticado
  Future<void> _loadSellerArticles() async {
    final String? userCode = SessionManager.activeUserCode.value;
    if (userCode == null ||
        userCode.trim().isEmpty ||
        !_hasSellerPermissions()) {
      if (!mounted) return;
      setState(() {
        _sellerArticles = [];
        _isLoading = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final articles = await _articleService.getSellerArticles(userCode);
    if (!mounted) return;

    setState(() {
      _sellerArticles = articles;
      _isLoading = false;
    });
  }

  // Renderizado dinamico de la imagen del articulo segun su origen
  Widget _buildArticleImage(String? imagePath) {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return const Center(
        child: Icon(Icons.image_not_supported, size: 30, color: Colors.grey),
      );
    }

    final cleanPath = imagePath.trim();

    if (cleanPath.startsWith('lib/assets/') || cleanPath.startsWith('assets/')) {
      return Image.asset(
        cleanPath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(Icons.broken_image, size: 30, color: Colors.grey),
          );
        },
      );
    }

    final file = File(cleanPath);
    if (cleanPath.startsWith('/') || file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(Icons.broken_image, size: 30, color: Colors.grey),
          );
        },
      );
    }

    return Image.asset(
      cleanPath,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(Icons.broken_image, size: 30, color: Colors.grey),
        );
      },
    );
  }

  // Construccion de la tarjeta superior con la imagen my_items_card.jpg
  Widget _buildTopBannerCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.asset(
        'lib/assets/images/my_items_card.png',
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/images/my_items_card.png',
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF5548F5).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(
                    Icons.store_rounded,
                    size: 48,
                    color: Color(0xFF5548F5),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Apertura de la interfaz de edicion precargada con el articulo seleccionado
  Future<void> _openEditArticle(Article article) async {
    final String? activeUserCode = SessionManager.activeUserCode.value;
    if (activeUserCode == null ||
        activeUserCode.trim().isEmpty ||
        !_hasSellerPermissions()) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PublishArticleScreen(
          articleToEdit: article,
          onArticleUpdated: () {
            _loadSellerArticles();
          },
        ),
      ),
    );

    if (mounted) {
      await _loadSellerArticles();
    }
  }

  // Ejecucion en dos etapas de advertencia irreversible y confirmacion definitiva
  Future<void> _startDeleteArticleFlow(Article article) async {
    final String? activeUserCode = SessionManager.activeUserCode.value;
    if (activeUserCode == null ||
        activeUserCode.trim().isEmpty ||
        !_hasSellerPermissions()) {
      return;
    }

    await LoadingDialog.show(
      context,
      title: 'Advertencia de Eliminación Permanente',
      subtitle:
      'Esta operación es permanente y no se puede deshacer. El artículo dejará de estar disponible en el catálogo de Happiley y deberás asumir las consecuencias de eliminar definitivamente tu publicación.',
      autoDismiss: true,
      duration: const Duration(seconds: 5),
      customSoundType: SystemSoundType.alert,
      customIcon: const Icon(
        Icons.warning_amber_rounded,
        color: Color(0xFFFFA000),
        size: 64,
      ),
    );

    if (!mounted) return;

    await AlertMessage.show(
      context: context,
      title: 'Eliminar Artículo',
      message:
      '¿Desea eliminar definitivamente el artículo "${article.name}" de sus publicaciones?',
      confirmText: 'Sí',
      cancelText: 'No',
      isConfirmDefault: false,
      playConfirmSound: false,
      onConfirm: () async {
        await _executeDeleteArticle(article);
      },
    );
  }

  // Eliminacion definitiva del articulo validando propiedad en base de datos
  Future<void> _executeDeleteArticle(Article article) async {
    final String? activeUserCode = SessionManager.activeUserCode.value;
    if (activeUserCode == null ||
        activeUserCode.trim().isEmpty ||
        !_hasSellerPermissions()) {
      return;
    }

    final bool deleted = await _articleService.deleteSellerArticle(
      articleId: article.id,
      sellerCode: activeUserCode,
    );

    if (!mounted) return;

    if (!deleted) {
      await LoadingDialog.show(
        context,
        title: 'Error al Eliminar',
        subtitle:
        'No se pudo eliminar el artículo o no pertenece a tu cuenta de vendedor.',
        autoDismiss: true,
        duration: const Duration(seconds: 3),
        customSoundType: SystemSoundType.error,
        customIcon: const Icon(
          Icons.error_outline_rounded,
          color: Color(0xFFE53935),
          size: 64,
        ),
      );
      return;
    }

    CartManager.selectedArticles.value = CartManager.selectedArticles.value
        .where((item) => item.id != article.id)
        .toList();
    await _persistenceService.deleteCartItem(article.id);

    SavedItemsManager.savedArticles.value = SavedItemsManager
        .savedArticles.value
        .where((item) => item.id != article.id)
        .toList();

    await _loadSellerArticles();
    if (!mounted) return;

    await LoadingDialog.show(
      context,
      title: '¡Artículo Eliminado!',
      subtitle:
      'El artículo ha sido eliminado definitivamente de tus publicaciones.',
      autoDismiss: true,
      duration: const Duration(seconds: 2),
      customSoundType: SystemSoundType.removeArticle,
      customIcon: const Icon(
        Icons.delete_forever_rounded,
        color: Color(0xFFE53935),
        size: 64,
      ),
    );
  }

  // Vista informativa cuando el vendedor aun no tiene articulos publicados
  Widget _buildEmptyStateView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: const Color(0xFF5548F5).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 40,
              color: Color(0xFF5548F5),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Aún no tienes artículos publicados',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Los artículos que publiques desde tu Panel de Vendedor aparecerán aquí para que puedas editarlos o eliminarlos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFF657080),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // Vista de bloqueo cuando no existe una sesion de vendedor autorizada
  Widget _buildRestrictedAccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFF5548F5).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_person_rounded,
                size: 40,
                color: Color(0xFF5548F5),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Acceso Restringido',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Debes iniciar sesión con una cuenta de vendedor autorizada para gestionar tus productos publicados.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Color(0xFF657080),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5548F5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LoginScreen(
                        onLoginSuccess: (_) {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.login_rounded),
                label: const Text(
                  'Ir a Iniciar Sesión',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Construccion de cada tarjeta individual del articulo publicado
  Widget _buildMyItemTile(Article article) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArticleDetailScreen(
                article: article,
                articlesList: _sellerArticles,
                onBack: () => Navigator.pop(context),
                onBuyNow: () => Navigator.pop(context),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Contenedor de imagen del articulo publicado
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildArticleImage(article.image),
                ),
              ),
              const SizedBox(width: 12),
              // Informacion general del articulo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppUtils.formatPrice(article.salePrice),
                      style: const TextStyle(
                        color: Color(0xFF5548F5),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Código: ${article.code}  |  Stock: ${article.stock}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Controles de edicion y eliminacion del articulo
              Row(
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF5548F5).withValues(alpha: 0.12),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        tooltip: 'Editar artículo',
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: Color(0xFF5548F5),
                        ),
                        onPressed: () => _openEditArticle(article),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Eliminar artículo',
                    onPressed: () => _startDeleteArticleFlow(article),
                    color: Colors.redAccent,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF5548F5),
        foregroundColor: Colors.white,
        title: const Text(
          'Mis Productos',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: ValueListenableBuilder<String?>(
        valueListenable: SessionManager.activeUserCode,
        builder: (context, activeUserCode, _) {
          if (activeUserCode == null ||
              activeUserCode.trim().isEmpty ||
              !_hasSellerPermissions()) {
            return _buildRestrictedAccessView();
          }

          if (_isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF5548F5),
              ),
            );
          }

          if (_sellerArticles.isEmpty) {
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: _buildTopBannerCard(),
                ),
                _buildEmptyStateView(),
              ],
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _sellerArticles.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: _buildTopBannerCard(),
                );
              }

              final articleIndex = index - 1;
              if (articleIndex >= _sellerArticles.length) {
                return const SizedBox.shrink();
              }

              return _buildMyItemTile(_sellerArticles[articleIndex]);
            },
          );
        },
      ),
    );
  }
}