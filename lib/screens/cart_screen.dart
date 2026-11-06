import 'package:flutter/material.dart';
import '../models/article.dart';
import '../services/cart_manager.dart';
import '../services/app_utils.dart';
import '../widgets/cart_item_card.dart';
import '../widgets/loading_dialog.dart';
import '../widgets/alert_message.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // Mapa de persistencia temporal para las cantidades asociadas al ID del articulo
  final Map<int, int> quantities = {};

  // Sincronizacion inicial del mapa de cantidades con los articulos activos en el carrito
  void _syncQuantities(List<Article> articles) {
    for (var article in articles) {
      if (!quantities.containsKey(article.id)) {
        quantities[article.id] = 1;
      }
    }
  }

  // Calculo del monto total acumulado multiplicando precio de venta por cantidad seleccionada
  double getTotal() {
    double total = 0.0;
    for (var article in CartManager.selectedArticles.value) {
      int count = quantities[article.id] ?? 1;
      total += article.salePrice * count;
    }
    return total;
  }

  // Incremento controlado de unidades respetando el limite de existencias disponible en stock
  void incrementQuantity(Article article) {
    setState(() {
      int current = quantities[article.id] ?? 1;
      if (current < article.stock) {
        quantities[article.id] = current + 1;
      }
    });
  }

  // Decremento de unidades con eliminacion automatica al reducir por debajo de la unidad
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

  // Remocion del articulo tanto del registro local de cantidades como del estado global del carrito
  void removeItem(Article article) {
    setState(() {
      quantities.remove(article.id);
      CartManager.toggleProduct(article);
    });
  }

  // Simulacion asincrona del procesamiento de pago y despliegue de dialogos de confirmacion
  Future<void> _processPurchase() async {
    LoadingDialog.show(
      context,
      title: 'Procesando compra',
      subtitle: 'Validando orden y pago...',
      autoDismiss: false,
      customIcon: const SizedBox(
        width: 40,
        height: 40,
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Color(0xFF5548F5),
          ),
          strokeWidth: 3.5,
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (!context.mounted) return;

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Barra superior principal con la identificacion de la pantalla del carrito
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
      // Escucha reactiva de la lista de articulos seleccionados en el gestor de carrito
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
              // Lista animada de articulos agregados al carrito
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
              // Panel inferior de resumen de costos y boton de confirmacion
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
                        onPressed: () {
                          AlertMessage.show(
                            context: context,
                            title: 'Confirmar Compra',
                            message: '¿Desea realizar la compra?',
                            confirmText: 'Sí',
                            cancelText: 'No',
                            isConfirmDefault: false,
                            onConfirm: _processPurchase,
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

  // Construccion del item individual de la tarjeta del carrito
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