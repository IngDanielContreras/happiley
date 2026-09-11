import 'package:flutter/material.dart';
import '../models/article.dart';
import '../services/cart_manager.dart';
import '../screens/article_detail_screen.dart';

class ArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback? onBuy;

  const ArticleCard({
    super.key,
    required this.article,
    this.onBuy,
  });

  String formatPrice(double price) {
    return '\$${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
          (match) => '${match.group(1)}.',
    )} COP';
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
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArticleDetailScreen(article: article),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen del producto
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      article.image!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Información general
              Text(
                article.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                formatPrice(article.salePrice),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                'Stock: ${article.stock}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 8),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5548F5),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onBuy,
                      child: const Text(
                        'Comprar',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  ValueListenableBuilder<List<Article>>(
                    valueListenable: CartManager.selectedArticles,
                    builder: (context, _, _) {
                      final isSelected = CartManager.isSelected(article);

                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? const Color(0xFF2D2DA8)
                              : Colors.grey.shade200,
                        ),
                        child: IconButton(
                          icon: Icon(
                            isSelected
                                ? Icons.shopping_cart
                                : Icons.shopping_cart_outlined,
                            color: isSelected ? Colors.white : Colors.grey.shade700,
                          ),
                          onPressed: () => CartManager.toggleProduct(article),
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