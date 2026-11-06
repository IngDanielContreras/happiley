import 'dart:io';
import 'package:flutter/material.dart';
import '../models/article.dart';
import '../services/cart_manager.dart';
import '../services/app_utils.dart';
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
    final bool isSelected = CartManager.isSelected(article);

    CartManager.toggleProduct(article);

    if (isSelected) {
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
    } else {
      await LoadingDialog.show(
        context,
        title: '¡Artículo Agregado!',
        subtitle: 'El artículo se ha añadido a tu carrito de compras.',
        autoDismiss: true,
        duration: const Duration(seconds: 2),
        customIcon: const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF4CAF50),
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
              // Imagen del producto adaptativa al espacio disponible
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildArticleImage(article.image),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Informacion general
              Text(
                article.name,
                maxLines: 1,
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

                  ValueListenableBuilder<List<Article>>(
                    valueListenable: CartManager.selectedArticles,
                    builder: (context, _, _) {
                      final isSelected = CartManager.isSelected(article);

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