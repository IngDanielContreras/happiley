import 'package:flutter/material.dart';
import '../models/article.dart';
import '../services/cart_manager.dart';
import '../services/app_utils.dart';
import '../widgets/cart_item_card.dart';
import '../widgets/loading_dialog.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final Map<int, int> quantities = {};

  void _syncQuantities(List<Article> articles) {
    for (var article in articles) {
      if (!quantities.containsKey(article.id)) {
        quantities[article.id] = 1;
      }
    }
  }

  double getTotal() {
    double total = 0.0;
    for (var article in CartManager.selectedArticles.value) {
      int count = quantities[article.id] ?? 1;
      total += article.salePrice * count;
    }
    return total;
  }

  void incrementQuantity(Article article) {
    setState(() {
      int current = quantities[article.id] ?? 1;
      if (current < article.stock) {
        quantities[article.id] = current + 1;
      }
    });
  }

  void decrementQuantity(Article article) {
    int current = quantities[article.id] ?? 1;
    if (current > 1) {
      setState(() {
        quantities[article.id] = current - 1;
      });
    } else {
      removeItem(article);
    }
  }

  void removeItem(Article article) {
    setState(() {
      quantities.remove(article.id);
      CartManager.toggleProduct(article);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF5548F5),
        foregroundColor: Colors.white,
        title: const Text(
          'Carrito de Compras',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: ValueListenableBuilder<List<Article>>(
        valueListenable: CartManager.selectedArticles,
        builder: (context, selectedList, _) {
          if (selectedList.isEmpty) {
            return const Center(
              child: Text(
                'El carrito esta vacio',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          _syncQuantities(selectedList);

          return Column(
            children: [
              Expanded(
                child: AnimatedList(
                  key: ValueKey(selectedList.length),
                  initialItemCount: selectedList.length,
                  itemBuilder: (context, index, animation) {
                    if (index >= selectedList.length) return const SizedBox();
                    final article = selectedList[index];

                    return FadeTransition(
                      opacity: CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInOut,
                      ),
                      child: SizeTransition(
                        sizeFactor: CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeInOut,
                        ),
                        child: _buildCartTile(article),
                      ),
                    );
                  },
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
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          AppUtils.formatPrice(getTotal()),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D2DA8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5548F5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          LoadingDialog.show(
                            context,
                            title: 'Procesando compra',
                            subtitle: 'Validando orden y pago...',
                            autoDismiss: false,
                          );

                          await Future.delayed(const Duration(seconds: 2));

                          if (!context.mounted) return;
                          Navigator.of(context, rootNavigator: true).pop();

                          if (!context.mounted) return;

                          // Diálogo con customIcon (usará la animación de entrada del chulo)
                          await LoadingDialog.show(
                            context,
                            title: '¡Compra Exitosa!',
                            subtitle: 'Tu pedido ha sido procesado correctamente.',
                            autoDismiss: true,
                            duration: const Duration(seconds: 3),
                            customIcon: const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF4CAF50),
                              size: 64,
                            ),
                          );

                          if (!context.mounted) return;

                          setState(() {
                            quantities.clear();
                            CartManager.clearCart();
                          });
                        },
                        child: const Text(
                          'Comprar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCartTile(Article article) {
    final qty = quantities[article.id] ?? 1;

    return CartItemCard(
      article: article,
      quantity: qty,
      onIncrement: () => incrementQuantity(article),
      onDecrement: () => decrementQuantity(article),
      onRemove: () => removeItem(article),
    );
  }
}