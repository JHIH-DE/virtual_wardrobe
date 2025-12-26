
enum GarmentCategory {
  top,
  bottom,
  outer,
  shoes,
  accessory,
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
    // Dart 2.17+ 可直接用 name，但這樣寫比較安全
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

class Garment {
  final String id;
  final String name;
  final GarmentCategory category;
  final String imageUrl;

  const Garment({
    required this.id,
    required this.name,
    required this.category,
    required this.imageUrl,
  });

  /// Example: from backend JSON
  factory Garment.fromJson(Map<String, dynamic> json) {
    return Garment(
      id: json['id'] as String,
      name: json['name'] as String,
      category:
      GarmentCategoryX.fromApiValue(json['category'] as String),
      imageUrl: json['image_url'] as String,
    );
  }

  /// Example: to backend JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.apiValue,
      'image_url': imageUrl,
    };
  }
}