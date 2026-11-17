import 'dart:io';
import 'package:flutter/material.dart';
import '../models/article.dart';
import '../screens/main_screen.dart';
import '../services/cart_manager.dart';
import '../services/saved_items_manager.dart';
import '../services/session_manager.dart';
import '../services/app_utils.dart';
import '../services/system_sound_manager.dart';
import '../widgets/loading_dialog.dart';

class ArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback? onBuy;
  final VoidCallback? onTap;

  const ArticleCard({
    super.key,
    required this.article,
    this.onBuy,
    this.onTap,
  });

  // Renderizado dinamico de la imagen segun su origen local o de assets.
  Widget _buildArticleImage(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return const Icon(
        Icons.image_not_supported,
        color: Colors.grey,
      );
    }

    final file = File(imagePath);
    if (imagePath.startsWith('/') || file.existsSync()) {
      return Image.file(
        file,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.broken_image,
          color: Colors.grey,
        ),
      );
    }

    return Image.asset(
      imagePath,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const Icon(
        Icons.broken_image,
        color: Colors.grey,
      ),
    );
  }

  Future<void> _handleCartIconPressed(BuildContext context) async {
    final String? activeUserCode = SessionManager.activeUserCode.value;
    if (!SessionManager.isLoggedIn ||
        activeUserCode == null ||
        activeUserCode.trim().isEmpty) {
      FocusScope.of(context).unfocus();
      MainScreenState.of(context)?.promptAuthentication(
        redirectToCartAfterLogin: false,
      );
      return;
    }

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

  // Gestion de guardado o eliminacion en la lista de deseos
  Future<void> _handleFavoriteIconPressed(BuildContext context) async {
    final String? activeUserCode = SessionManager.activeUserCode.value;
    if (!SessionManager.isLoggedIn ||
        activeUserCode == null ||
        activeUserCode.trim().isEmpty) {
      FocusScope.of(context).unfocus();
      MainScreenState.of(context)?.promptAuthentication(
        redirectToCartAfterLogin: false,
      );
      return;
    }

    final bool wasSaved = SavedItemsManager.isSaved(article);
    final bool operationSuccess =
    await SavedItemsManager.toggleSavedItem(article);

    if (!context.mounted) return;

    if (!operationSuccess) {
      await LoadingDialog.show(
        context,
        title: 'Error de Guardado',
        subtitle: 'No se pudo actualizar tu lista de deseos.',
        autoDismiss: true,
        duration: const Duration(seconds: 2),
        customSoundType: SystemSoundType.error,
        customIcon: const Icon(
          Icons.error_outline_rounded,
          color: Color(0xFFE53935),
          size: 64,
        ),
      );
      return;
    }

    if (wasSaved) {
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
    } else {
      await LoadingDialog.show(
        context,
        title: '¡Artículo Guardado!',
        subtitle: 'El artículo se ha añadido a tu lista de deseos.',
        autoDismiss: true,
        duration: const Duration(seconds: 2),
        customSoundType: SystemSoundType.savedItem,
        customIcon: const Icon(
          Icons.favorite_rounded,
          color: Color(0xFFE53935),
          size: 64,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen del producto adaptativa al espacio disponible con boton de favoritos
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildArticleImage(article.image),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: ValueListenableBuilder<String?>(
                            valueListenable: SessionManager.activeUserCode,
                            builder: (context, activeUserCode, _) {
                              final bool isAuthenticated =
                                  activeUserCode != null &&
                                      activeUserCode.trim().isNotEmpty;

                              return ValueListenableBuilder<List<Article>>(
                                valueListenable:
                                SavedItemsManager.savedArticles,
                                builder: (context, _, _) {
                                  final bool isSaved = isAuthenticated &&
                                      SavedItemsManager.isSaved(article);

                                  return SizedBox(
                                    width: 34,
                                    height: 34,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color:
                                        Colors.white.withValues(alpha: 0.92),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.12,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        iconSize: 19,
                                        tooltip: isSaved
                                            ? 'Quitar de favoritos'
                                            : 'Guardar en favoritos',
                                        icon: Icon(
                                          isSaved
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: isSaved
                                              ? const Color(0xFFE53935)
                                              : Colors.grey.shade700,
                                        ),
                                        onPressed: () {
                                          _handleFavoriteIconPressed(context);
                                        },
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Informacion general
              SizedBox(
                height: 36,
                child: Text(
                  article.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ),

              const SizedBox(height: 4),

              Text(
                AppUtils.formatPrice(article.salePrice),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                'Stock: ${article.stock}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 11,
                ),
              ),

              const SizedBox(height: 6),

              // Botones de accion
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5548F5),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: onBuy,
                        child: const Text(
                          'Comprar',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  ValueListenableBuilder<String?>(
                    valueListenable: SessionManager.activeUserCode,
                    builder: (context, activeUserCode, _) {
                      final bool isAuthenticated = activeUserCode != null &&
                          activeUserCode.trim().isNotEmpty;

                      return ValueListenableBuilder<List<Article>>(
                        valueListenable: CartManager.selectedArticles,
                        builder: (context, _, _) {
                          final isSelected = isAuthenticated &&
                              CartManager.isSelected(article);

                          return SizedBox(
                            width: 36,
                            height: 36,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? const Color(0xFF2D2DA8)
                                    : Colors.grey.shade200,
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                iconSize: 20,
                                icon: Icon(
                                  isSelected
                                      ? Icons.shopping_cart
                                      : Icons.shopping_cart_outlined,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                ),
                                onPressed: () {
                                  _handleCartIconPressed(context);
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}