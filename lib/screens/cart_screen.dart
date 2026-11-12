import 'package:flutter/material.dart';
import '../models/article.dart';
import '../services/cart_manager.dart';
import '../services/app_utils.dart';
import '../services/session_manager.dart';
import '../services/system_sound_manager.dart';
import '../services/notification_service.dart';
import '../database/purchase_service.dart';
import '../widgets/cart_item_card.dart';
import '../widgets/loading_dialog.dart';
import '../widgets/alert_message.dart';
import 'login_screen.dart';

class CartScreen extends StatefulWidget {
  final VoidCallback? onRequestLogin;

  const CartScreen({
    super.key,
    this.onRequestLogin,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // Mapa de persistencia temporal para las cantidades asociadas al ID del articulo
  final Map<int, int> quantities = {};
  final PurchaseService _purchaseService = PurchaseService();
  bool _isProcessingPurchase = false;

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
    int current = quantities[article.id] ?? 1;
    if (current < article.stock) {
      setState(() {
        quantities[article.id] = current + 1;
      });
      SystemSoundManager().playAddArticle();
    }
  }

  // Decremento de unidades con eliminacion automatica al reducir por debajo de la unidad
  void decrementQuantity(Article article) {
    int current = quantities[article.id] ?? 1;
    if (current > 1) {
      setState(() {
        quantities[article.id] = current - 1;
      });
      SystemSoundManager().playRemoveArticle();
    } else {
      removeItem(article);
      SystemSoundManager().playRemoveArticle();
    }
  }

  // Remocion del articulo tanto del registro local de cantidades como del estado global del carrito
  void removeItem(Article article) {
    setState(() {
      quantities.remove(article.id);
      CartManager.toggleProduct(article);
    });
  }

  // Redireccion hacia la pantalla de inicio de sesion
  void _navigateToLogin() {
    if (widget.onRequestLogin != null) {
      widget.onRequestLogin!();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoginScreen(
          onLoginSuccess: (_) {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
      ),
    );
  }

  // Ejecucion persistente y atomica del procesamiento de compra
  Future<void> _processPurchase() async {
    if (_isProcessingPurchase) return;

    final String? activeUser = SessionManager.activeUserCode.value;
    if (activeUser == null || activeUser.isEmpty) {
      await LoadingDialog.show(
        context,
        title: 'Acceso Restringido',
        subtitle: 'Debes iniciar sesión para realizar una compra.',
        autoDismiss: true,
        duration: const Duration(seconds: 3),
        customSoundType: SystemSoundType.error,
        customIcon: const Icon(
          Icons.lock_outline_rounded,
          color: Color(0xFFE53935),
          size: 56,
        ),
      );
      return;
    }

    _isProcessingPurchase = true;

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

    final List<Article> articlesSnapshot =
    List<Article>.from(CartManager.selectedArticles.value);
    final Map<int, int> quantitiesSnapshot = Map<int, int>.from(quantities);

    final PurchaseExecutionResult result =
    await _purchaseService.executePurchase(
      articles: articlesSnapshot,
      quantities: quantitiesSnapshot,
    );

    if (!mounted) {
      _isProcessingPurchase = false;
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();

    if (!mounted) {
      _isProcessingPurchase = false;
      return;
    }

    if (result.success) {
      await NotificationService().notifyPurchaseSuccess(
        userCode: activeUser,
        purchaseCode: result.purchaseCode ?? '',
        totalItems: result.totalUnits,
        formattedTotal: AppUtils.formatPrice(result.totalAmount),
      );

      if (!mounted) {
        _isProcessingPurchase = false;
        return;
      }

      setState(() {
        quantities.clear();
        CartManager.clearCart();
      });

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
    } else {
      final String errorReason =
          result.errorMessage ?? 'No se pudo registrar la compra.';

      await NotificationService().notifyPurchaseFailed(
        userCode: activeUser,
        reason: errorReason,
      );

      if (!mounted) {
        _isProcessingPurchase = false;
        return;
      }

      await LoadingDialog.show(
        context,
        title: 'Compra Fallida',
        subtitle: errorReason,
        autoDismiss: true,
        duration: const Duration(seconds: 4),
        customSoundType: SystemSoundType.error,
        customIcon: const Icon(
          Icons.cancel_rounded,
          color: Color(0xFFE53935),
          size: 64,
        ),
      );
    }

    _isProcessingPurchase = false;
  }

  // Vista informativa de bloqueo cuando no existe una sesion activa
  Widget _buildRestrictedAccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFF5548F5).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_person_rounded,
                size: 40,
                color: Color(0xFF5548F5),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Acceso Restringido al Carrito',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Debes iniciar sesión con tu cuenta de Happiley para visualizar tu carrito y realizar compras.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Color(0xFF657080),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5548F5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: _navigateToLogin,
                icon: const Icon(Icons.login_rounded),
                label: const Text(
                  'Ir a Iniciar Sesión',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
      body: ValueListenableBuilder<String?>(
        valueListenable: SessionManager.activeUserCode,
        builder: (context, activeUserCode, _) {
          if (activeUserCode == null || activeUserCode.isEmpty) {
            return _buildRestrictedAccessView();
          }

          // Escucha reactiva de la lista de articulos seleccionados en el gestor de carrito
          return ValueListenableBuilder<List<Article>>(
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
                        if (index >= selectedList.length) {
                          return const SizedBox();
                        }
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