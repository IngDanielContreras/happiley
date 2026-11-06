import 'dart:io';
import 'package:flutter/material.dart';
import '../models/article.dart';
import '../screens/article_detail_screen.dart';
import '../services/app_utils.dart';
import 'alert_message.dart';

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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // Contenedor dinamico de la imagen del articulo
              Container(
                width: 60,
                height: 60,
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
                      maxLines: 1,
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
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Botones de incremento y decremento de unidades
                    Row(
                      children: [
                        Container(
                          height: 30,
                          width: 30,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.remove, size: 16),
                            onPressed: onDecrement,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '$quantity',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Container(
                          height: 30,
                          width: 30,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.add, size: 16),
                            onPressed: onIncrement,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Boton de remocion con cuadro de dialogo de confirmacion
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () {
                  AlertMessage.show(
                    context: context,
                    title: 'Eliminar Artículo',
                    message: '¿Desea borrar el artículo?',
                    confirmText: 'Sí',
                    cancelText: 'No',
                    isConfirmDefault: false,
                    onConfirm: onRemove,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}