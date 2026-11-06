import 'dart:io';
import 'package:flutter/material.dart';
import '../models/article.dart';
import '../screens/article_detail_screen.dart';
import '../services/app_utils.dart';
import 'alert_message.dart';
import 'loading_dialog.dart';

class CartItemCard extends StatelessWidget {
  final Article article;
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const CartItemCard({
    super.key,
    required this.article,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  // Renderizado dinamico de la imagen segun su origen local o de assets
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

  Future<void> _showDeleteLoadingDialog(BuildContext context) async {
    await LoadingDialog.show(
      context,
      title: '¡Artículo Eliminado!',
      subtitle: 'El artículo ha sido eliminado del carrito.',
      autoDismiss: true,
      duration: const Duration(seconds: 2),
      customIcon: const Icon(
        Icons.remove_shopping_cart_rounded,
        color: Color(0xFFE53935),
        size: 64,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('cart_item_${article.id}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {
        DismissDirection.endToStart: 0.4,
      },
      confirmDismiss: (direction) async {
        bool shouldDelete = false;

        await AlertMessage.show(
          context: context,
          title: 'Eliminar Artículo',
          message: '¿Desea borrar el artículo?',
          confirmText: 'Sí',
          cancelText: 'No',
          isConfirmDefault: false,
          onConfirm: () {
            shouldDelete = true;
          },
        );

        return shouldDelete;
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
      onDismissed: (direction) {
        onRemove();
        _showDeleteLoadingDialog(context);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Navegacion a la vista detallada del articulo seleccionado
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ArticleDetailScreen(
                  article: article,
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
                // Informacion textual del producto y controles de cantidad
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
                        AppUtils.formatPrice(article.salePrice * quantity),
                        style: const TextStyle(
                          color: Color(0xFF5548F5),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                // Botones de incremento y decremento de unidades
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: onDecrement,
                      color: Colors.grey.shade700,
                    ),
                    Text(
                      '$quantity',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: onIncrement,
                      color: const Color(0xFF5548F5),
                    ),
                    // Boton de remocion con cuadro de dialogo de confirmacion
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        AlertMessage.show(
                          context: context,
                          title: 'Eliminar Artículo',
                          message: '¿Desea borrar el artículo?',
                          confirmText: 'Sí',
                          cancelText: 'No',
                          isConfirmDefault: false,
                          onConfirm: () async {
                            onRemove();
                            await _showDeleteLoadingDialog(context);
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
}