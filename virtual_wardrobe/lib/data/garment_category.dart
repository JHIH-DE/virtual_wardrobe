import 'dart:ui';

import 'package:flutter/material.dart';

enum GarmentCategory {
  top,
  bottom,
  outer,
  dress,
  shoes,
  accessory,
}

extension GarmentCategoryX on GarmentCategory {
  String get label {
    switch (this) {
      case GarmentCategory.top:
        return 'Top';
      case GarmentCategory.bottom:
        return 'Bottom';
      case GarmentCategory.outer:
        return 'Outer';
      case GarmentCategory.dress:
        return 'Dress';
      case GarmentCategory.shoes:
        return 'Shoes';
      case GarmentCategory.accessory:
        return 'Accessory';
    }
  }

  String get apiValue {
    switch (this) {
      case GarmentCategory.top:
        return 'top';
      case GarmentCategory.bottom:
        return 'bottom';
      case GarmentCategory.outer:
        return 'outer';
      case GarmentCategory.dress:
        return 'dress';
      case GarmentCategory.shoes:
        return 'shoes';
      case GarmentCategory.accessory:
        return 'accessory';
    }
  }

  static GarmentCategory fromApiValue(String? value) {
    if (value == null) return GarmentCategory.top;
    return GarmentCategory.values.firstWhere(
      (e) => e.apiValue == value,
      orElse: () => GarmentCategory.top,
    );
  }
}

enum GarmentSubCategory {
  // Tops
  tShirt,
  shirt,
  sweater,
  hoodie,
  tankTop,
  polo,
  blouse,

  // Bottoms
  pants,
  jeans,
  shorts,
  skirt,
  leggings,

  // Outer
  jacket,
  coat,
  blazer,
  cardigan,
  vest,

  // Dress
  dress,
  jumpsuit,

  // Shoes
  sneakers,
  boots,
  sandals,
  heels,
  loafers,
  flats,

  // Accessories
  hat,
  bag,
  belt,
  scarf,
  jewelry,
  sunglasses,

  other,
}

extension GarmentSubCategoryX on GarmentSubCategory {
  String get label {
    switch (this) {
      case GarmentSubCategory.tShirt: return 'T-Shirt';
      case GarmentSubCategory.shirt: return 'Shirt';
      case GarmentSubCategory.sweater: return 'Sweater';
      case GarmentSubCategory.hoodie: return 'Hoodie';
      case GarmentSubCategory.tankTop: return 'Tank Top';
      case GarmentSubCategory.polo: return 'Polo';
      case GarmentSubCategory.blouse: return 'Blouse';
      case GarmentSubCategory.pants: return 'Pants';
      case GarmentSubCategory.jeans: return 'Jeans';
      case GarmentSubCategory.shorts: return 'Shorts';
      case GarmentSubCategory.skirt: return 'Skirt';
      case GarmentSubCategory.leggings: return 'Leggings';
      case GarmentSubCategory.jacket: return 'Jacket';
      case GarmentSubCategory.coat: return 'Coat';
      case GarmentSubCategory.blazer: return 'Blazer';
      case GarmentSubCategory.cardigan: return 'Cardigan';
      case GarmentSubCategory.vest: return 'Vest';
      case GarmentSubCategory.dress: return 'Dress';
      case GarmentSubCategory.jumpsuit: return 'Jumpsuit';
      case GarmentSubCategory.sneakers: return 'Sneakers';
      case GarmentSubCategory.boots: return 'Boots';
      case GarmentSubCategory.sandals: return 'Sandals';
      case GarmentSubCategory.heels: return 'Heels';
      case GarmentSubCategory.loafers: return 'Loafers';
      case GarmentSubCategory.flats: return 'Flats';
      case GarmentSubCategory.hat: return 'Hat';
      case GarmentSubCategory.bag: return 'Bag';
      case GarmentSubCategory.belt: return 'Belt';
      case GarmentSubCategory.scarf: return 'Scarf';
      case GarmentSubCategory.jewelry: return 'Jewelry';
      case GarmentSubCategory.sunglasses: return 'Sunglasses';
      case GarmentSubCategory.other: return 'Other';
    }
  }

  String get apiValue => name;

  static GarmentSubCategory fromApiValue(String? value) {
    if (value == null) return GarmentSubCategory.other;
    return GarmentSubCategory.values.firstWhere(
      (e) => e.apiValue == value,
      orElse: () => GarmentSubCategory.other,
    );
  }
}

enum GarmentColor {
  black, white, grey, beige, cream, brown, navy, blue, green, olive, khaki, red, burgundy, yellow, orange, pink, purple,
}

extension GarmentColorX on GarmentColor {
  String get label {
    final n = name;
    return n[0].toUpperCase() + n.substring(1);
  }

  Color get color {
    switch (this) {
      case GarmentColor.black: return Colors.black;
      case GarmentColor.white: return Colors.white;
      case GarmentColor.grey: return Colors.grey;
      case GarmentColor.beige: return const Color(0xFFF5F5DC);
      case GarmentColor.cream: return const Color(0xFFFFFDD0);
      case GarmentColor.brown: return Colors.brown;
      case GarmentColor.navy: return const Color(0xFF1A237E);
      case GarmentColor.blue: return Colors.blue;
      case GarmentColor.green: return Colors.green;
      case GarmentColor.olive: return const Color(0xFF556B2F);
      case GarmentColor.red: return Colors.red;
      case GarmentColor.burgundy: return const Color(0xFF800020);
      case GarmentColor.yellow: return Colors.yellow;
      case GarmentColor.orange: return Colors.orange;
      case GarmentColor.pink: return Colors.pink;
      case GarmentColor.purple: return Colors.purple;
      case GarmentColor.khaki: return const Color(0xFFC3B091);
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

class OutfitSelection {
  final Garment? top;
  final Garment? middle;
  final Garment? outer;
  final Garment? bottom;
  final Garment? shoes;
  final Garment? accessory;

  const OutfitSelection({
    this.top,
    this.middle,
    this.outer,
    this.bottom,
    this.shoes,
    this.accessory,
  });

  bool get canTryOn => (top != null || middle != null) && bottom != null;

  OutfitSelection copyWith({
    Garment? top,
    Garment? middle,
    Garment? outer,
    Garment? bottom,
    Garment? shoes,
    Garment? accessory,
    bool clearMiddle = false,
    bool clearOuter = false,
    bool clearShoes = false,
    bool clearAccessory = false,
  }) {
    return OutfitSelection(
      top: top ?? this.top,
      middle: clearMiddle ? null : (middle ?? this.middle),
      outer: clearOuter ? null : (outer ?? this.outer),
      bottom: bottom ?? this.bottom,
      shoes: clearShoes ? null : (shoes ?? this.shoes),
      accessory: clearAccessory ? null : (accessory ?? this.accessory),
    );
  }
}

class Garment {
  final int? id;
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

  const Garment({
    required this.name,
    required this.category,
    required this.subCategory,
    required this.uploadUrl,
    required this.objectName,
    this.thickness = 0.0,
    this.formality = 0.0,
    this.id,
    this.brand,
    this.color,
    this.price,
    this.purchaseDate,
    this.imageUrl,
  });

  Garment copyWith({
    int? id,
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
    bool clearId = false,
    bool clearBrand = false,
    bool clearColor = false,
    bool clearPrice = false,
    bool clearPurchaseDate = false,
  }) {
    return Garment(
      id: clearId ? null : (id ?? this.id),
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
      purchaseDate: clearPurchaseDate ? null : (purchaseDate ?? this.purchaseDate),
    );
  }

  factory Garment.fromJson(Map<String, dynamic> json) {
    DateTime? _parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    double? _parseNum(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return Garment(
      id: json['id'] as int?,
      name: (json['name'] as String?) ?? '',
      brand: json['brand'] as String?,
      color: json['color'] as String?,
      price: _parseNum(json['price']),
      thickness: _parseNum(json['thickness']) ?? 0.0,
      formality: _parseNum(json['formality']) ?? 0.0,
      purchaseDate: _parseDate(json['purchase_date']),
      category: GarmentCategoryX.fromApiValue(json['category'] as String?),
      subCategory: (json['sub_category'] as String?) ?? '',
      uploadUrl: (json['upload_url'] as String?) ?? '',
      objectName: (json['object_name'] as String?) ?? '',
      imageUrl: (json['image_url'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'color': color,
      'price': price,
      'thickness': thickness,
      'formality': formality,
      'subCategory': subCategory,
      'category': category.apiValue,
      'purchase_date': purchaseDate?.toIso8601String(),
      'upload_url': uploadUrl,
      'object_name': objectName,
      'image_url': imageUrl,
    };
  }
}
