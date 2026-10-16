import 'dart:math';
import 'package:flutter/material.dart';
import '../database/article_service.dart';
import '../models/article.dart';
import '../widgets/article_card.dart';
import '../services/cart_manager.dart';
import '../widgets/custom_app_bar.dart';

class ExploreScreen extends StatefulWidget {
  final VoidCallback onCartPressed;
  final ValueChanged<Article>? onArticleSelected;

  const ExploreScreen({
    super.key,
    required this.onCartPressed,
    this.onArticleSelected,
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with TickerProviderStateMixin {
  final ArticleService databaseService = ArticleService();

  List<Article> articles = [];
  List<Article> filteredArticles = [];
  bool isLoading = true;
  TabController? tabController;
  static const int articlesPerPage = 10;

  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadArticles();
  }

  // Carga de articulos desde la base de datos local (no en tiempo real)
  Future<void> loadArticles() async {
    try {
      final articlesObtained = await databaseService.getArticles();

      setState(() {
        articles = articlesObtained;
        filteredArticles = articlesObtained;
        isLoading = false;
        _updatePagination();
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

  // Filtrado de articulos segun los criterios de busqueda ingresados
  void _filterArticles(String query) {
    final cleanQuery = query.toLowerCase().trim();

    setState(() {
      searchQuery = query;

      if (cleanQuery.isEmpty) {
        filteredArticles = List.from(articles);
      } else {
        filteredArticles = articles.where((article) {
          final articleName = article.name.toLowerCase();
          return articleName.contains(cleanQuery);
        }).toList();
      }

      _updatePagination();
    });
  }

  // Actualizacion de la paginacion y controlador de pestañas (en la visualizacion de articulos)
  void _updatePagination() {
    final pageCount = max(1, (filteredArticles.length / articlesPerPage).ceil());

    tabController?.dispose();
    tabController = TabController(
      length: pageCount,
      vsync: this,
    );
  }

  // Formateo de los precios en pesos colombianos (COP)
  String formatPrice(double price) {
    return '\$${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
          (match) => '${match.group(1)}.',
    )} COP';
  }

  // Obtencion de la lista de articulos correspondientes a la pagina actual
  List<Article> articlesForPage(int page) {
    final start = page * articlesPerPage;

    final end = min(
      start + articlesPerPage,
      filteredArticles.length,
    );

    if (start >= filteredArticles.length) {
      return [];
    }

    return filteredArticles.sublist(start, end);
  }

  @override
  void dispose() {
    searchController.dispose();
    tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int totalPages = tabController?.length ?? 1;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: const CustomAppBar(
          title: 'Explorar Artículos',
        ),
        body: isLoading
            ? const Center(
          child: CircularProgressIndicator(),
        )
            : Column(
          children: [
            // Barra de busqueda de articulo
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: searchController,
                onChanged: _filterArticles,
                decoration: InputDecoration(
                  hintText: 'Buscar productos...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF657080),
                  ),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      color: Color(0xFF657080),
                    ),
                    onPressed: () {
                      searchController.clear();
                      _filterArticles('');
                    },
                  )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF2F4F7),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(
                      color: Color(0xFFE1E5EB),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(
                      color: Color(0xFF5548F5),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: filteredArticles.isEmpty
                  ? const Center(
                child: Text(
                  'No se encontraron coincidencias.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF657080),
                  ),
                ),
              )
                  : TabBarView(
                key: ValueKey('tab_view_${filteredArticles.length}_$searchQuery'),
                controller: tabController,
                children: List.generate(
                  totalPages,
                      (page) {
                    final pageArticles = articlesForPage(page);

                    return CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                final article = pageArticles[index];

                                return ArticleCard(
                                  article: article,
                                  onTap: () {
                                    FocusScope.of(context).unfocus();
                                    if (widget.onArticleSelected !=
                                        null) {
                                      widget.onArticleSelected!(
                                        article,
                                      );
                                    }
                                  },
                                  onBuy: () {
                                    FocusScope.of(context).unfocus();
                                    if (!CartManager.isSelected(
                                        article)) {
                                      CartManager.toggleProduct(
                                        article,
                                      );
                                    }
                                    widget.onCartPressed();
                                  },
                                );
                              },
                              childCount: pageArticles.length,
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

                        if (totalPages > 1)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                bottom: 24,
                                top: 8,
                              ),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius:
                                    BorderRadius.circular(25),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: IntrinsicWidth(
                                    child: TabBar(
                                      controller: tabController,
                                      isScrollable: true,
                                      tabAlignment:
                                      TabAlignment.center,
                                      dividerColor:
                                      Colors.transparent,
                                      indicator:
                                      const BoxDecoration(
                                        color: Color(0xFF5548F5),
                                        shape: BoxShape.circle,
                                      ),
                                      indicatorSize:
                                      TabBarIndicatorSize.tab,
                                      labelColor: Colors.white,
                                      unselectedLabelColor:
                                      Colors.grey.shade700,
                                      labelStyle: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      labelPadding:
                                      const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      tabs: List.generate(
                                        totalPages,
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
            ),
          ],
        ),

        // Boton flotante de acceso rapido al carrito de compras
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
              onPressed: () {
                FocusScope.of(context).unfocus();
                widget.onCartPressed();
              },
            );
          },
        ),
      ),
    );
  }
}