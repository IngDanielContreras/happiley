// Modelo de datos para articulos de la tienda
class Article {
  final int id;
  final String code;
  final String name;
  final String description;
  final double purchasePrice;
  final double salePrice;
  final int stock;
  final String purchaseDate;
  final String? saleDate;
  final int unitsUntilReorder;
  final String supportEndDate;
  final String? image;
  final String? sellerCode;

  Article({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.purchasePrice,
    required this.salePrice,
    required this.stock,
    required this.purchaseDate,
    this.saleDate,
    required this.unitsUntilReorder,
    required this.supportEndDate,
    this.image,
    this.sellerCode,
  });

  // Conversion desde mapa de base de datos a objeto Dart
  factory Article.fromMap(Map<String, dynamic> map) {
    return Article(
      id: map['id'],
      code: map['code'],
      name: map['name'],
      description: map['description'],
      purchasePrice: (map['purchase_price'] as num).toDouble(),
      salePrice: (map['sale_price'] as num).toDouble(),
      stock: map['stock'],
      purchaseDate: map['purchase_date'],
      saleDate: map['sale_date'],
      unitsUntilReorder: map['units_until_reorder'],
      supportEndDate: map['support_end_date'],
      image: map['image'],
      sellerCode: map['seller_code']?.toString(),
    );
  }

  // Conversion a mapa para operaciones de insercion y actualizacion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
      'purchase_price': purchasePrice,
      'sale_price': salePrice,
      'stock': stock,
      'purchase_date': purchaseDate,
      'sale_date': saleDate,
      'units_until_reorder': unitsUntilReorder,
      'support_end_date': supportEndDate,
      'image': image,
      'seller_code': sellerCode,
    };
  }
}