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
  final String id;
  final String name;

  final String? brand;
  final String? color;
  final GarmentSeason? season;
  final double? price;
  final DateTime? purchaseDate;

  final GarmentCategory category;

  /// Supports either a network URL or local file path (demo/local mode)
  final String imageUrl;

  const Garment({
    required this.id,
    required this.name,
    required this.category,
    required this.imageUrl,
    this.brand,
    this.color,
    this.season,
    this.price,
    this.purchaseDate,
  });

  Garment copyWith({
    String? id,
    String? name,
    String? brand,
    String? color,
    GarmentSeason? season,
    double? price,
    DateTime? purchaseDate,
    GarmentCategory? category,
    String? imageUrl,
    bool clearBrand = false,
    bool clearColor = false,
    bool clearSeason = false,
    bool clearPrice = false,
    bool clearPurchaseDate = false,
  }) {
    return Garment(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      brand: clearBrand ? null : (brand ?? this.brand),
      color: clearColor ? null : (color ?? this.color),
      season: clearSeason ? null : (season ?? this.season),
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
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      brand: json['brand'] as String?,
      color: json['color'] as String?,
      season: (json['season'] is String)
          ? GarmentSeasonX.fromApiValue(json['season'] as String)
          : null,
      price: _parsePrice(json['price']),
      purchaseDate: _parseDate(json['purchase_date']),
      category: GarmentCategoryX.fromApiValue(json['category'] as String),
      imageUrl: (json['image_url'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'color': color,
      'season': season?.apiValue,
      'price': price,
      'purchase_date': purchaseDate?.toIso8601String(),
      'category': category.apiValue,
      'image_url': imageUrl,
    };
  }
}