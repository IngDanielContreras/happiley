import 'dart:math';
import 'package:flutter/material.dart';
import '../database/article_service.dart';
import '../models/article.dart';
import '../widgets/article_card.dart';
import '../services/cart_manager.dart';

class ExploreScreen extends StatefulWidget {
  final VoidCallback onCartPressed;

  const ExploreScreen({
    super.key,
    required this.onCartPressed,
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with SingleTickerProviderStateMixin {
  final ArticleService databaseService = ArticleService();

  List<Article> articles = [];
  bool isLoading = true;
  TabController? tabController;
  static const int articlesPerPage = 10;

  @override
  void initState() {
    super.initState();
    loadArticles();
  }

  Future<void> loadArticles() async {
    try {
      final articlesObtained =
      await databaseService.getArticles();

      final pageCount =
      max(1, (articlesObtained.length / articlesPerPage).ceil());

      tabController = TabController(
        length: pageCount,
        vsync: this,
      );

      setState(() {
        articles = articlesObtained;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudieron cargar los artículos: $e',
          ),
        ),
      );
    }
  }

  String formatPrice(double price) {
    return '\$${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
          (match) => '${match.group(1)}.',
    )} COP';
  }

  List<Article> articlesForPage(int page) {
    final start = page * articlesPerPage;

    final end = min(
      start + articlesPerPage,
      articles.length,
    );

    if (start >= articles.length) {
      return [];
    }

    return articles.sublist(start, end);
  }

  @override
  void dispose() {
    tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF5548F5),
        foregroundColor: Colors.white,
        title: const Text(
          'Explorar Artículos',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : articles.isEmpty
          ? const Center(
        child: Text(
          'No hay artículos disponibles.',
          style: TextStyle(fontSize: 16),
        ),
      )
          : TabBarView(
        controller: tabController,
        children: List.generate(
          tabController!.length,
              (page) {
            final pageArticles =
            articlesForPage(page);

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    delegate:
                    SliverChildBuilderDelegate(
                          (context, index) {
                        final article =
                        pageArticles[index];

                        return ArticleCard(
                          article: article,
                          onBuy: () {
                            CartManager.toggleProduct(article);
                          },
                        );
                      },
                      childCount:
                      pageArticles.length,
                    ),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.68,
                    ),
                  ),
                ),

                // Paginación al final de la página
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                    const EdgeInsets.only(
                      bottom: 24,
                      top: 8,
                    ),
                    child: Center(
                      child: Container(
                        padding:
                        const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                          Colors.grey.shade100,
                          borderRadius:
                          BorderRadius.circular(25),
                          border: Border.all(
                            color:
                            Colors.grey.shade300,
                          ),
                        ),
                        child: IntrinsicWidth(
                          child: TabBar(
                            controller:
                            tabController,
                            isScrollable: true,
                            tabAlignment:
                            TabAlignment.center,
                            dividerColor:
                            Colors.transparent,
                            indicator:
                            const BoxDecoration(
                              color:
                              Color(0xFF5548F5),
                              shape: BoxShape.circle,
                            ),
                            indicatorSize:
                            TabBarIndicatorSize.tab,
                            labelColor: Colors.white,
                            unselectedLabelColor:
                            Colors.grey.shade700,
                            labelStyle:
                            const TextStyle(
                              fontWeight:
                              FontWeight.bold,
                            ),
                            labelPadding:
                            const EdgeInsets.symmetric(
                              horizontal: 3,
                            ),
                            tabs: List.generate(
                              tabController!.length,
                                  (index) {
                                return Tab(
                                  child: SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),

      // Boton flotante de carrito
      floatingActionButton: ValueListenableBuilder<List<Article>>(
        valueListenable: CartManager.selectedArticles,
        builder: (context, articles, _) {
          final count = articles.length;

          return FloatingActionButton.extended(
            backgroundColor: const Color(0xFF2D2DA8),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.shopping_cart_outlined),
            label: count == 0
                ? const SizedBox.shrink()
                : Text(
              '$count',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: widget.onCartPressed,
          );
        },
      ),
    );
  }
}