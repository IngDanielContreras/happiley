import 'dart:io';
import 'package:flutter/material.dart';
import '../models/article.dart';
import '../services/saved_items_manager.dart';
import '../services/cart_manager.dart';
import '../services/app_utils.dart';
import '../services/session_manager.dart';
import '../services/system_sound_manager.dart';
import '../widgets/alert_message.dart';
import '../widgets/loading_dialog.dart';
import 'article_detail_screen.dart';
import 'login_screen.dart';

class SavedItemsScreen extends StatefulWidget {
  final VoidCallback? onBuyNowRedirect;

  const SavedItemsScreen({
    super.key,
    this.onBuyNowRedirect,
  });

  @override
  State<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends State<SavedItemsScreen> {
  @override
  void initState() {
    super.initState();
    // Sincronizacion inicial con la base de datos del usuario activo
    SavedItemsManager.loadSavedItems();
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

  // Construccion de la tarjeta superior
  Widget _buildTopBannerCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.asset(
        'lib/assets/images/saved_items_card.png',
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/images/saved_items_card.png',
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
                    Icons.favorite_rounded,
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

  // Dialogo temporal de confirmacion al eliminar un articulo de favoritos
  Future<void> _showUnsavedLoadingDialog() async {
    if (!mounted) return;
    await LoadingDialog.show(
      context,
      title: '¡Artículo Eliminado!',
      subtitle: 'El artículo ha sido eliminado de tu lista de deseos.',
      autoDismiss: true,
      duration: const Duration(seconds: 2),
      customSoundType: SystemSoundType.unsavedItem,
      customIcon: const Icon(
        Icons.heart_broken_rounded,
        color: Color(0xFFE53935),
        size: 64,
      ),
    );
  }

  // Eliminacion persistente del articulo de la lista de deseos
  Future<bool> _removeSavedArticle(Article article) async {
    final bool removed = await SavedItemsManager.removeSavedItem(article);
    if (!mounted) return removed;

    if (removed) {
      await _showUnsavedLoadingDialog();
    } else {
      await LoadingDialog.show(
        context,
        title: 'Error al Eliminar',
        subtitle: 'No se pudo eliminar el artículo de tu lista de deseos.',
        autoDismiss: true,
        duration: const Duration(seconds: 2),
        customSoundType: SystemSoundType.error,
        customIcon: const Icon(
          Icons.error_outline_rounded,
          color: Color(0xFFE53935),
          size: 64,
        ),
      );
    }

    return removed;
  }

  // Alternancia del articulo en el carrito desde la lista de deseos
  Future<void> _handleCartToggle(Article article) async {
    final bool isSelected = CartManager.isSelected(article);
    CartManager.toggleProduct(article);

    if (isSelected) {
      await LoadingDialog.show(
        context,
        title: '¡Artículo Eliminado!',
        subtitle: 'El artículo ha sido eliminado del carrito.',
        autoDismiss: true,
        duration: const Duration(seconds: 2),
        customSoundType: SystemSoundType.removeArticle,
        customIcon: const Icon(
          Icons.remove_shopping_cart_rounded,
          color: Color(0xFFE53935),
          size: 64,
        ),
      );
    } else {
      await LoadingDialog.show(
        context,
        title: '¡Artículo Agregado!',
        subtitle: 'El artículo se ha añadido a tu carrito de compras.',
        autoDismiss: true,
        duration: const Duration(seconds: 2),
        customSoundType: SystemSoundType.addArticle,
        customIcon: const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF4CAF50),
          size: 64,
        ),
      );
    }
  }

  // Vista informativa cuando la lista de deseos no contiene articulos
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
              Icons.favorite_border_rounded,
              size: 40,
              color: Color(0xFF5548F5),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Tu Lista de Deseos está vacía',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Guarda los artículos que más te gusten presionando el corazón en Explorar para encontrarlos aquí.',
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

  // Vista informativa de bloqueo cuando no existe una sesion activa
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
              'Debes iniciar sesión con tu cuenta de Happiley para visualizar tu lista de deseos.',
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

  // Construccion de cada tarjeta individual con el estilo de CartItemCard
  Widget _buildSavedItemTile(Article article, List<Article> savedList) {
    return Dismissible(
      key: ValueKey('saved_item_${article.id}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {
        DismissDirection.endToStart: 0.4,
      },
      confirmDismiss: (direction) async {
        bool shouldDelete = false;

        await AlertMessage.show(
          context: context,
          title: 'Eliminar Artículo',
          message: '¿Desea eliminar el artículo de su lista de deseos?',
          confirmText: 'Sí',
          cancelText: 'No',
          isConfirmDefault: false,
          playConfirmSound: false,
          onConfirm: () {
            shouldDelete = true;
          },
        );

        if (!shouldDelete) return false;
        return await _removeSavedArticle(article);
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFE53935),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(
              Icons.delete_outline,
              color: Colors.white,
              size: 26,
            ),
            SizedBox(width: 8),
            Text(
              'Eliminar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
      child: Card(
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
                  articlesList: savedList,
                  onBack: () => Navigator.pop(context),
                  onBuyNow: () {
                    Navigator.pop(context);
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                    widget.onBuyNowRedirect?.call();
                  },
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Contenedor dinamico de la imagen del articulo
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
                // Informacion textual del producto guardado
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
                        'Stock: ${article.stock}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                // Acciones rapidas de carrito y eliminacion de favoritos
                Row(
                  children: [
                    ValueListenableBuilder<List<Article>>(
                      valueListenable: CartManager.selectedArticles,
                      builder: (context, _, _) {
                        final bool inCart = CartManager.isSelected(article);

                        return SizedBox(
                          width: 36,
                          height: 36,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: inCart
                                  ? const Color(0xFF2D2DA8)
                                  : Colors.grey.shade200,
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 20,
                              tooltip: inCart
                                  ? 'Quitar del carrito'
                                  : 'Agregar al carrito',
                              icon: Icon(
                                inCart
                                    ? Icons.shopping_cart
                                    : Icons.shopping_cart_outlined,
                                color: inCart
                                    ? Colors.white
                                    : Colors.grey.shade700,
                              ),
                              onPressed: () => _handleCartToggle(article),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Eliminar de favoritos',
                      onPressed: () {
                        AlertMessage.show(
                          context: context,
                          title: 'Eliminar Artículo',
                          message:
                          '¿Desea eliminar el artículo de su lista de deseos?',
                          confirmText: 'Sí',
                          cancelText: 'No',
                          isConfirmDefault: false,
                          playConfirmSound: false,
                          onConfirm: () async {
                            await _removeSavedArticle(article);
                          },
                        );
                      },
                      color: Colors.redAccent,
                    ),
                  ],
                ),
              ],
            ),
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
          'Lista de Deseos',
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
          if (activeUserCode == null || activeUserCode.trim().isEmpty) {
            return _buildRestrictedAccessView();
          }

          return ValueListenableBuilder<List<Article>>(
            valueListenable: SavedItemsManager.savedArticles,
            builder: (context, savedList, _) {
              if (savedList.isEmpty) {
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
                itemCount: savedList.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: _buildTopBannerCard(),
                    );
                  }

                  final articleIndex = index - 1;
                  if (articleIndex >= savedList.length) {
                    return const SizedBox.shrink();
                  }

                  final article = savedList[articleIndex];
                  return _buildSavedItemTile(article, savedList);
                },
              );
            },
          );
        },
      ),
    );
  }
}