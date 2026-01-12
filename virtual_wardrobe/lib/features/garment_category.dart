import 'dart:ui';
import 'package:flutter/material.dart';

enum GarmentCategory {
  top,
  bottom,
  outer,
  shoes,
  accessory,
}

enum GarmentColor {
  black,
  white,
  gray,
  beige,
  brown,
  navy,
  blue,
  green,
  olive,
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
      case GarmentColor.gray:
        return Colors.grey;
      case GarmentColor.beige:
        return const Color(0xFFF5F5DC);
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
    }
  }

  /// For visibility on very light colors.
  Color get preferredCheckColor {
    switch (this) {
      case GarmentColor.white:
      case GarmentColor.yellow:
      case GarmentColor.beige:
        return Colors.black;
      default:
        return Colors.white;
    }
  }
}

extension GarmentCategoryX on GarmentCategory {
  /// For UI display
  String get label {
    switch (this) {
      case GarmentCategory.top:
        return 'Top';
      case GarmentCategory.bottom:
        return 'Bottom';
      case GarmentCategory.outer:
        return 'Outer';
      case GarmentCategory.shoes:
        return 'Shoes';
      case GarmentCategory.accessory:
        return 'Accessory';
    }
  }

  /// For API request / response
  String get apiValue {
    switch (this) {
      case GarmentCategory.top:
        return 'top';
      case GarmentCategory.bottom:
        return 'bottom';
      case GarmentCategory.outer:
        return 'outer';
      case GarmentCategory.shoes:
        return 'shoes';
      case GarmentCategory.accessory:
        return 'accessory';
    }
  }

  /// Parse from API string
  static GarmentCategory fromApiValue(String value) {
    return GarmentCategory.values.firstWhere(
          (e) => e.apiValue == value,
      orElse: () => GarmentCategory.top,
    );
  }
}

enum GarmentSeason { spring, summer, autumn, winter, all }

extension GarmentSeasonX on GarmentSeason {
  String get label {
    switch (this) {
      case GarmentSeason.spring:
        return 'Spring';
      case GarmentSeason.summer:
        return 'Summer';
      case GarmentSeason.autumn:
        return 'Autumn';
      case GarmentSeason.winter:
        return 'Winter';
      case GarmentSeason.all:
        return 'All seasons';
    }
  }

  String get apiValue {
    switch (this) {
      case GarmentSeason.spring:
        return 'spring';
      case GarmentSeason.summer:
        return 'summer';
      case GarmentSeason.autumn:
        return 'autumn';
      case GarmentSeason.winter:
        return 'winter';
      case GarmentSeason.all:
        return 'all';
    }
  }

  static GarmentSeason fromApiValue(String value) {
    return GarmentSeason.values.firstWhere(
          (e) => e.apiValue == value,
      orElse: () => GarmentSeason.all,
    );
  }
}

class OutfitSelection {
  final Garment? top;
  final Garment? bottom;
  final Garment? outer;
  final Garment? shoes;
  final Garment? accessory;

  const OutfitSelection({
    this.top,
    this.bottom,
    this.outer,
    this.shoes,
    this.accessory,
  });

  bool get canTryOn => top != null && bottom != null;

  OutfitSelection copyWith({
    Garment? top,
    Garment? bottom,
    Garment? outer,
    Garment? shoes,
    Garment? accessory,
    bool clearOuter = false,
    bool clearShoes = false,
    bool clearAccessory = false,
  }) {
    return OutfitSelection(
      top: top ?? this.top,
      bottom: bottom ?? this.bottom,
      outer: clearOuter ? null : (outer ?? this.outer),
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
  final GarmentSeason season;
  final double? price;
  final DateTime? purchaseDate;
  final String? imageUrl;

  final GarmentCategory category;

  /// Supports either a network URL or local file path (demo/local mode)
  final String uploadUrl;
  final String objectName;
  final String publicUrl;

  const Garment({
    required this.name,
    required this.category,
    required this.uploadUrl,
    required this.objectName,
    required this.publicUrl,
    required this.season,
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
    GarmentSeason? season,
    double? price,
    DateTime? purchaseDate,
    GarmentCategory? category,
    String? uploadUrl,
    String? objectName,
    String? publicUrl,
    String? imageUrl,
    bool clearId = false,
    bool clearBrand = false,
    bool clearColor = false,
    bool clearPrice = false,
    bool clearPurchaseDate = false,
  }) {
    return Garment(
      name: name ?? this.name,
      category: category ?? this.category,
      uploadUrl: uploadUrl ?? this.uploadUrl,
      objectName: objectName ?? this.objectName,
      publicUrl: publicUrl ?? this.publicUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      id: clearId ? null : (id ?? this. id),
      brand: clearBrand ? null : (brand ?? this.brand),
      color: clearColor ? null : (color ?? this.color),
      season: season ?? this.season,
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

    double? _parsePrice(dynamic v) {
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
      season: GarmentSeasonX.fromApiValue(json['season'] as String),
      price: _parsePrice(json['price']),
      purchaseDate: _parseDate(json['purchase_date']),
      category: GarmentCategoryX.fromApiValue(json['category'] as String),
      uploadUrl: (json['upload_url'] as String?) ?? '',
      objectName: (json['object_name'] as String?) ?? '',
      publicUrl: (json['public_url'] as String?) ?? '',
      imageUrl: (json['image_url'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'color': color,
      'season': season.apiValue,
      'price': price,
      'purchase_date': purchaseDate?.toIso8601String(),
      'category': category.apiValue,
      'upload_url': uploadUrl,
      'object_name': objectName,
      'public_url': publicUrl,
      'image_url': imageUrl,
    };
  }
}