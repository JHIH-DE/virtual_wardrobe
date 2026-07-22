import 'package:flutter/material.dart';

enum GarmentCategory { top, bottom, outer, onePiece, socks, shoes, accessory }

extension GarmentCategoryX on GarmentCategory {
  String get label {
    switch (this) {
      case GarmentCategory.top:
        return 'Top';
      case GarmentCategory.bottom:
        return 'Bottom';
      case GarmentCategory.outer:
        return 'Outer';
      case GarmentCategory.onePiece:
        return 'One-piece';
      case GarmentCategory.socks:
        return 'Socks';
      case GarmentCategory.shoes:
        return 'Shoes';
      case GarmentCategory.accessory:
        return 'Accessory';
    }
  }

  String get apiValue => label;

  static GarmentCategory fromApiValue(String? value) {
    if (value == null) return GarmentCategory.top;
    final lower = value.toLowerCase();
    return GarmentCategory.values.firstWhere(
      (e) => e.apiValue.toLowerCase() == lower,
      orElse: () => GarmentCategory.top,
    );
  }
}

enum GarmentColor {
  black,
  white,
  grey,
  beige,
  cream,
  brown,
  navy,
  blue,
  green,
  olive,
  khaki,
  red,
  burgundy,
  yellow,
  orange,
  pink,
  purple,
}

extension GarmentColorX on GarmentColor {
  String get label {
    final n = name;
    return n[0].toUpperCase() + n.substring(1);
  }

  Color get color {
    switch (this) {
      case GarmentColor.black:
        return Colors.black;
      case GarmentColor.white:
        return Colors.white;
      case GarmentColor.grey:
        return Colors.grey;
      case GarmentColor.beige:
        return const Color(0xFFF5F5DC);
      case GarmentColor.cream:
        return const Color(0xFFFFFDD0);
      case GarmentColor.brown:
        return Colors.brown;
      case GarmentColor.navy:
        return const Color(0xFF1A237E);
      case GarmentColor.blue:
        return Colors.blue;
      case GarmentColor.green:
        return Colors.green;
      case GarmentColor.olive:
        return const Color(0xFF556B2F);
      case GarmentColor.red:
        return Colors.red;
      case GarmentColor.burgundy:
        return const Color(0xFF800020);
      case GarmentColor.yellow:
        return Colors.yellow;
      case GarmentColor.orange:
        return Colors.orange;
      case GarmentColor.pink:
        return Colors.pink;
      case GarmentColor.purple:
        return Colors.purple;
      case GarmentColor.khaki:
        return const Color(0xFFC3B091);
    }
  }

  Color get preferredCheckColor {
    switch (this) {
      case GarmentColor.white:
      case GarmentColor.yellow:
      case GarmentColor.beige:
      case GarmentColor.cream:
      case GarmentColor.khaki:
        return Colors.black;
      default:
        return Colors.white;
    }
  }
}

class Garment {
  final int? id;
  final int? garmentId;
  final String name;
  final String? brand;
  final String? color;
  final double? price;
  final DateTime? purchaseDate;
  final String? imageUrl;
  final GarmentCategory category;
  final String subCategory;
  final double thickness;
  final double formality;
  final String uploadUrl;
  final String objectName;
  final Map<String, dynamic>? metadata;
  final bool isFavorite;

  const Garment({
    required this.name,
    required this.category,
    required this.subCategory,
    required this.uploadUrl,
    required this.objectName,
    this.thickness = 0.0,
    this.formality = 0.0,
    this.isFavorite = false,
    this.id,
    this.garmentId,
    this.brand,
    this.color,
    this.price,
    this.purchaseDate,
    this.imageUrl,
    this.metadata,
  });

  Garment copyWith({
    int? id,
    int? garmentId,
    String? name,
    String? brand,
    String? color,
    double? price,
    DateTime? purchaseDate,
    GarmentCategory? category,
    String? subCategory,
    double? thickness,
    double? formality,
    String? uploadUrl,
    String? objectName,
    String? imageUrl,
    Map<String, dynamic>? metadata,
    bool? isFavorite,
    bool clearId = false,
    bool clearGarmentId = false,
    bool clearBrand = false,
    bool clearColor = false,
    bool clearPrice = false,
    bool clearPurchaseDate = false,
    bool clearMetadata = false,
  }) {
    return Garment(
      id: clearId ? null : (id ?? this.id),
      garmentId: clearGarmentId ? null : (garmentId ?? this.garmentId),
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      thickness: thickness ?? this.thickness,
      formality: formality ?? this.formality,
      name: name ?? this.name,
      brand: clearBrand ? null : (brand ?? this.brand),
      uploadUrl: uploadUrl ?? this.uploadUrl,
      objectName: objectName ?? this.objectName,
      imageUrl: imageUrl ?? this.imageUrl,
      color: clearColor ? null : (color ?? this.color),
      price: clearPrice ? null : (price ?? this.price),
      purchaseDate: clearPurchaseDate
          ? null
          : (purchaseDate ?? this.purchaseDate),
      metadata: clearMetadata ? null : (metadata ?? this.metadata),
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  factory Garment.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    double? parseNum(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return Garment(
      id: json['id'] as int?,
      garmentId: json['garment_id'] as int?,
      name: (json['name'] as String?) ?? '',
      brand: json['brand'] as String?,
      color: json['color'] as String?,
      price: parseNum(json['price']),
      thickness: parseNum(json['thickness']) ?? 0.0,
      formality: parseNum(json['formality']) ?? 0.0,
      purchaseDate: parseDate(json['purchase_date']),
      category: GarmentCategoryX.fromApiValue(json['category'] as String?),
      subCategory: (json['sub_category'] as String?) ?? '',
      uploadUrl: (json['upload_url'] as String?) ?? '',
      objectName: (json['object_name'] as String?) ?? '',
      imageUrl: (json['image_url'] as String?) ?? '',
      metadata: json['metadata'] as Map<String, dynamic>?,
      isFavorite: (json['is_favorite'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'garment_id': garmentId,
      'name': name,
      'brand': brand,
      'color': color,
      'price': price,
      'thickness': thickness,
      'formality': formality,
      'sub_category': subCategory,
      'category': category.apiValue,
      'purchase_date': purchaseDate?.toIso8601String(),
      'upload_url': uploadUrl,
      'object_name': objectName,
      'image_url': imageUrl,
      'metadata': metadata,
    };
  }
}
