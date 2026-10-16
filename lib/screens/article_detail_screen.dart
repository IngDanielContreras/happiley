import 'package:flutter/material.dart';
import '../models/article.dart';
import '../services/cart_manager.dart';
import '../widgets/custom_app_bar.dart';
import 'image_viewer_screen.dart';

class ArticleDetailScreen extends StatelessWidget {
  final Article article;
  final VoidCallback onBack;
  final VoidCallback onBuyNow;

  const ArticleDetailScreen({
    super.key,
    required this.article,
    required this.onBack,
    required this.onBuyNow,
  });

  // Formato del precio en pesos colombianos (COP)
  String formatPrice(double price) {
    return '\$${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
          (match) => '${match.group(1)}.',
    )} COP';
  }

  // Adicion del producto al carrito y activacion de flujo de compra inmediata
  void _buyNow() {
    if (!CartManager.isSelected(article)) {
      CartManager.toggleProduct(article);
    }

    onBuyNow();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar.statusOnly(),
      body: SafeArea(
        child: Column(
          children: [
            // Contenedor superior con la imagen del articulo y boton de regreso
            Stack(
              children: [
                Container(
                  height: 250,
                  width: double.infinity,
                  color: Colors.grey.shade100,
                  child: GestureDetector(
                    onTap: () {
                      if (article.image == null ||
                          article.image!.isEmpty) {
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ImageViewerScreen(
                            imagePath: article.image!,
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: article.image != null &&
                          article.image!.isNotEmpty
                          ? Image.asset(
                        article.image!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 60,
                              color: Colors.grey,
                            ),
                          );
                        },
                      )
                          : const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          size: 60,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.black,
                      ),
                      onPressed: onBack,
                    ),
                  ),
                ),
              ],
            ),

            // Seccion detallada con información del articulo (precio, stock y descripcion del producto)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre principal del producto
                      Text(
                        article.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Fila con el precio y el stock disponible
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              formatPrice(article.salePrice),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D2DA8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Stock: ${article.stock}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Encabezado de la seccion de descripcion del producto
                      const Text(
                        'Descripción del Producto',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        article.description.isNotEmpty
                            ? article.description
                            : 'Sin descripción disponible.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Barra inferior con botones de accion para comprar y agregar el articulo al carrito
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(12),
                    blurRadius: 5,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Boton principal para compra inmediata
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5548F5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                      onPressed: _buyNow,
                      child: const Text(
                        'Comprar Ahora',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Boton circular para agregar o quitar el articulo del carrito
                  ValueListenableBuilder<List<Article>>(
                    valueListenable: CartManager.selectedArticles,
                    builder: (context, selectedArticles, child) {
                      final isSelected =
                      CartManager.isSelected(article);

                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? const Color(0xFF2D2DA8)
                              : Colors.grey.shade200,
                        ),
                        child: IconButton(
                          tooltip: isSelected
                              ? 'Quitar del carrito'
                              : 'Agregar al carrito',
                          icon: Icon(
                            isSelected
                                ? Icons.shopping_cart
                                : Icons.shopping_cart_outlined,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                          onPressed: () {
                            CartManager.toggleProduct(article);
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}