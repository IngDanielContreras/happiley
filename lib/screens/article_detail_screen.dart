import 'dart:io';
import 'package:flutter/material.dart';
import '../models/article.dart';
import '../services/cart_manager.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/article_description_viewer.dart';
import 'image_viewer_screen.dart';

class ArticleDetailScreen extends StatefulWidget {
  final Article article;
  final List<Article> articlesList;
  final VoidCallback onBack;
  final VoidCallback onBuyNow;
  final ValueChanged<Article>? onArticleChanged;

  const ArticleDetailScreen({
    super.key,
    required this.article,
    this.articlesList = const [],
    required this.onBack,
    required this.onBuyNow,
    this.onArticleChanged,
  });

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  late PageController _pageController;
  late int _initialIndex;

  @override
  void initState() {
    super.initState();

    _initialIndex = widget.articlesList.indexWhere(
          (a) => a.id == widget.article.id,
    );

    if (_initialIndex == -1) {
      _initialIndex = 0;
    }

    _pageController = PageController(initialPage: _initialIndex);
  }

  @override
  void didUpdateWidget(covariant ArticleDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.articlesList != widget.articlesList &&
        widget.articlesList.isNotEmpty) {
      final newIndex = widget.articlesList.indexWhere(
            (a) => a.id == widget.article.id,
      );

      if (newIndex != -1 && _pageController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(newIndex);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.articlesList.isEmpty) {
      return ArticleDetailContent(
        article: widget.article,
        onBack: widget.onBack,
        onBuyNow: widget.onBuyNow,
      );
    }

    return PageView.builder(
      controller: _pageController,
      physics: const ClampingScrollPhysics(),
      itemCount: widget.articlesList.length,
      onPageChanged: (index) {
        widget.onArticleChanged?.call(widget.articlesList[index]);
      },
      itemBuilder: (context, index) {
        return ArticleDetailContent(
          article: widget.articlesList[index],
          onBack: widget.onBack,
          onBuyNow: widget.onBuyNow,
        );
      },
    );
  }
}

class ArticleDetailContent extends StatelessWidget {
  final Article article;
  final VoidCallback onBack;
  final VoidCallback onBuyNow;

  const ArticleDetailContent({
    super.key,
    required this.article,
    required this.onBack,
    required this.onBuyNow,
  });

  String formatPrice(double price) {
    return '\$${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
          (match) => '${match.group(1)}.',
    )} COP';
  }

  void _buyNow() {
    if (!CartManager.isSelected(article)) {
      CartManager.toggleProduct(article);
    }

    onBuyNow();
  }

  Widget _buildArticleImage(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return const Center(
        child: Icon(
          Icons.image_not_supported,
          size: 60,
          color: Colors.grey,
        ),
      );
    }

    final file = File(imagePath);

    if (imagePath.startsWith('/') || file.existsSync()) {
      return Image.file(
        file,
        width: double.infinity,
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
      );
    }

    return Image.asset(
      imagePath,
      width: double.infinity,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar.statusOnly(),
      body: SafeArea(
        child: Column(
          children: [
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
                      borderRadius: BorderRadius.zero,
                      child: _buildArticleImage(article.image),
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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                      const Text(
                        'Descripción del Producto',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ArticleDescriptionViewer(
                        description: article.description,
                      ),
                    ],
                  ),
                ),
              ),
            ),
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