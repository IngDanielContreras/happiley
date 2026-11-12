import 'package:sqflite/sqflite.dart';

import '../models/article.dart';
import '../services/session_manager.dart';
import 'article_service.dart';

class PurchaseExecutionResult {
  final bool success;
  final String? purchaseCode;
  final String? errorMessage;
  final double totalAmount;
  final int totalUnits;

  const PurchaseExecutionResult({
    required this.success,
    this.purchaseCode,
    this.errorMessage,
    this.totalAmount = 0.0,
    this.totalUnits = 0,
  });
}

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;

  PurchaseService._internal();

  final ArticleService _articleService = ArticleService();
  bool _tablesInitialized = false;

  Future<Database> _getDb() async {
    final db = await _articleService.database;
    if (!_tablesInitialized) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS purchases (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          purchase_code TEXT NOT NULL UNIQUE,
          user_code TEXT NOT NULL,
          status TEXT NOT NULL,
          purchase_date TEXT NOT NULL,
          purchase_time TEXT NOT NULL,
          created_at_iso TEXT NOT NULL,
          timezone_offset TEXT NOT NULL,
          total_amount REAL NOT NULL,
          discount_amount REAL NOT NULL DEFAULT 0.0,
          total_units INTEGER NOT NULL,
          notes TEXT,
          failure_reason TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS purchase_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          purchase_id INTEGER NOT NULL,
          purchase_code TEXT NOT NULL,
          article_id INTEGER NOT NULL,
          article_code TEXT NOT NULL,
          article_name TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          unit_price REAL NOT NULL,
          subtotal REAL NOT NULL,
          FOREIGN KEY (purchase_id) REFERENCES purchases(id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_purchases_user_code
        ON purchases (user_code)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_purchase_items_purchase_id
        ON purchase_items (purchase_id)
      ''');

      _tablesInitialized = true;
    }
    return db;
  }

  String _formatTimezoneOffset(Duration offset) {
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hours:$minutes';
  }

  Future<PurchaseExecutionResult> executePurchase({
    required List<Article> articles,
    required Map<int, int> quantities,
    double discountAmount = 0.0,
  }) async {
    final String? userCode = SessionManager.activeUserCode.value;
    if (userCode == null || userCode.trim().isEmpty) {
      return const PurchaseExecutionResult(
        success: false,
        errorMessage: 'Debes iniciar sesión para realizar una compra.',
      );
    }

    if (articles.isEmpty) {
      return const PurchaseExecutionResult(
        success: false,
        errorMessage: 'No hay artículos seleccionados en el carrito.',
      );
    }

    final db = await _getDb();
    final now = DateTime.now();
    final purchaseDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final purchaseTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final createdAtIso = now.toIso8601String();
    final timezoneOffset = _formatTimezoneOffset(now.timeZoneOffset);
    final purchaseCode = 'CMP-${now.millisecondsSinceEpoch}';

    try {
      double computedTotal = 0.0;
      int computedUnits = 0;

      await db.transaction((txn) async {
        final validatedLines = List.empty(growable: true);

        for (final article in articles) {
          final int requestedQty = quantities[article.id] ?? 1;
          if (requestedQty <= 0) {
            throw StateError(
              'La cantidad solicitada para "${article.name}" no es válida.',
            );
          }

          final currentRows = await txn.query(
            'articles',
            where: 'id = ?',
            whereArgs: [article.id],
            limit: 1,
          );

          if (currentRows.isEmpty) {
            throw StateError(
              'El artículo "${article.name}" ya no se encuentra disponible.',
            );
          }

          final currentArticle = Article.fromMap(currentRows.first);
          if (currentArticle.stock < requestedQty) {
            throw StateError(
              'Stock insuficiente para "${currentArticle.name}" (disponible: ${currentArticle.stock}).',
            );
          }

          final double unitPrice = currentArticle.salePrice;
          final double subtotal = unitPrice * requestedQty;

          computedTotal += subtotal;
          computedUnits += requestedQty;

          validatedLines.add({
            'article_id': currentArticle.id,
            'article_code': currentArticle.code,
            'article_name': currentArticle.name,
            'quantity': requestedQty,
            'unit_price': unitPrice,
            'subtotal': subtotal,
            'new_stock': currentArticle.stock - requestedQty,
          });
        }

        final double netTotal = (computedTotal - discountAmount).clamp(
          0.0,
          double.infinity,
        );

        final int purchaseId = await txn.insert('purchases', {
          'purchase_code': purchaseCode,
          'user_code': userCode,
          'status': 'COMPLETED',
          'purchase_date': purchaseDate,
          'purchase_time': purchaseTime,
          'created_at_iso': createdAtIso,
          'timezone_offset': timezoneOffset,
          'total_amount': netTotal,
          'discount_amount': discountAmount,
          'total_units': computedUnits,
          'notes': 'Compra registrada desde carrito Happiley',
          'failure_reason': null,
        });

        for (final line in validatedLines) {
          await txn.insert('purchase_items', {
            'purchase_id': purchaseId,
            'purchase_code': purchaseCode,
            'article_id': line['article_id'],
            'article_code': line['article_code'],
            'article_name': line['article_name'],
            'quantity': line['quantity'],
            'unit_price': line['unit_price'],
            'subtotal': line['subtotal'],
          });

          await txn.update(
            'articles',
            {'stock': line['new_stock'], 'sale_date': purchaseDate},
            where: 'id = ?',
            whereArgs: [line['article_id']],
          );
        }

        computedTotal = netTotal;
      });

      return PurchaseExecutionResult(
        success: true,
        purchaseCode: purchaseCode,
        totalAmount: computedTotal,
        totalUnits: computedUnits,
      );
    } catch (e) {
      final String reason = e is StateError
          ? e.message
          : 'Error de integridad al registrar la transacción.';

      try {
        await db.insert('purchases', {
          'purchase_code': '$purchaseCode-ERR',
          'user_code': userCode,
          'status': 'FAILED',
          'purchase_date': purchaseDate,
          'purchase_time': purchaseTime,
          'created_at_iso': createdAtIso,
          'timezone_offset': timezoneOffset,
          'total_amount': 0.0,
          'discount_amount': discountAmount,
          'total_units': 0,
          'notes': 'Intento de compra fallido',
          'failure_reason': reason,
        });
      } catch (_) {}

      return PurchaseExecutionResult(success: false, errorMessage: reason);
    }
  }
}
