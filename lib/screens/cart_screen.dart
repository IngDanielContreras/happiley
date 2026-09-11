import 'package:flutter/material.dart';
import '../models/article.dart';
import '../services/cart_manager.dart';
import '../services/app_utils.dart';
import '../widgets/cart_item_card.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // Mapa de cantidades por artículo
  final Map<int, int> quantities = {};

  // Sincronización de cantidades registradas
  void _syncQuantities(List<Article> articles) {
    for (var article in articles) {
      if (!quantities.containsKey(article.id)) {
        quantities[article.id] = 1;
      }
    }
  }

  // Calculo del precio total acumulado
  double getTotal() {
    double total = 0.0;
    for (var article in CartManager.selectedArticles.value) {
      int count = quantities[article.id] ?? 1;
      total += article.salePrice * count;
    }
    return total;
  }

  // Incremento de la cantidad
  void incrementQuantity(Article article) {
    setState(() {
      int current = quantities[article.id] ?? 1;
      if (current < article.stock) {
        quantities[article.id] = current + 1;
      }
    });
  }

  // Decremento de la cantidad
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

  // Eliminación del artículo seleccionado
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
                'El carrito está vacío',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          // Sincronización de registros
          _syncQuantities(selectedList);

          return Column(
            children: [
              // Lista de productos en el carrito
              Expanded(
                child: AnimatedList(
                  key: ValueKey(selectedList.length),
                  initialItemCount: selectedList.length,
                  itemBuilder: (context, index, animation) {
                    if (index >= selectedList.length) return const SizedBox();
                    final article = selectedList[index];

                    // Transición de desvanecido y tamaño
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

              // Contenedor del total y botón de compra
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
                    // Muestra del total
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

                    // Procesamiento de compra
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5548F5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          // Limpieza total del carrito
                          setState(() {
                            quantities.clear();
                            CartManager.clearCart();
                          });

                          // Notificación de compra exitosa
                          AppUtils.showSnackBar(
                            context,
                            '¡Compra Realizada con Éxito!',
                          );
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

  // Construcción de tarjeta de producto
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