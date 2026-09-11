class Article {
  final int id;
  final String code;
  final String name;
  final String description;
  final double purchasePrice;
  final double salePrice;
  final int stock;
  final String? purchaseDate;
  final String? saleDate;
  final int unitsUntilReorder;
  final String? supportEndDate;
  final String? image;

  Article({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.purchasePrice,
    required this.salePrice,
    required this.stock,
    this.purchaseDate,
    this.saleDate,
    required this.unitsUntilReorder,
    this.supportEndDate,
    this.image,
  });

  factory Article.fromMap(Map<String, dynamic> map) {
    return Article(
      id: map['id'] as int,
      code: map['code'] as String,
      name: map['name'] as String,
      description: map['description'] ?? '',
      purchasePrice: (map['purchase_price'] as num).toDouble(),
      salePrice: (map['sale_price'] as num).toDouble(),
      stock: map['stock'] as int,
      purchaseDate: map['purchase_date'] as String?,
      saleDate: map['sale_date'] as String?,
      unitsUntilReorder: map['units_until_reorder'] as int,
      supportEndDate: map['support_end_date'] as String?,
      image: map['image'] as String?,
    );
  }
}