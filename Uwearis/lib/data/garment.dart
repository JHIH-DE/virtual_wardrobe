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

enum GarmentFit { slim, regular, relaxed, oversized }

extension GarmentFitX on GarmentFit {
  String get label {
    final n = name;
    return n[0].toUpperCase() + n.substring(1);
  }

  String get apiValue => label;

  static GarmentFit? fromApiValue(String? value) {
    if (value == null) return null;
    final lower = value.toLowerCase();
    for (final f in GarmentFit.values) {
      if (f.name.toLowerCase() == lower || f.label.toLowerCase() == lower) {
        return f;
      }
    }
    return null;
  }
}

/// Categories a garment's [GarmentFit] applies to — cut/silhouette is a
/// meaningful choice for clothing with a body shape, not for shoes or
/// accessories.
const Set<GarmentCategory> garmentFitCategories = {
  GarmentCategory.top,
  GarmentCategory.bottom,
  GarmentCategory.outer,
  GarmentCategory.onePiece,
};

class Garment {
  final int? id;
  final int? garmentId;
  final String name;
  final String? brand;
  final String? color;
  final String? fit;
  final double? price;
  final DateTime? purchaseDate;
  final String? imageUrl;
  final GarmentCategory category;
  final String subCategory;

  /// Backend-side these are integer scales (0–5); the model matches. Not
  /// read by any UI today — parsed and echoed straight back on upload.
  final int thickness;
  final int formality;
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
    this.thickness = 0,
    this.formality = 0,
    this.isFavorite = false,
    this.id,
    this.garmentId,
    this.brand,
    this.color,
    this.fit,
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
    String? fit,
    double? price,
    DateTime? purchaseDate,
    GarmentCategory? category,
    String? subCategory,
    int? thickness,
    int? formality,
    String? uploadUrl,
    String? objectName,
    String? imageUrl,
    Map<String, dynamic>? metadata,
    bool? isFavorite,
    bool clearId = false,
    bool clearGarmentId = false,
    bool clearBrand = false,
    bool clearColor = false,
    bool clearFit = false,
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
      fit: clearFit ? null : (fit ?? this.fit),
      price: clearPrice ? null : (price ?? this.price),
      purchaseDate: clearPurchaseDate
          ? null
          : (purchaseDate ?? this.purchaseDate),
      metadata: clearMetadata ? null : (metadata ?? this.metadata),
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  /// Parses a nullable API identifier (`id` / `garment_id`).
  ///
  /// These arrive as whole JSON numbers. Unlike the general numeric fields
  /// ([parseIntField] in [fromJson]) this deliberately does **not** accept a
  /// numeric string, and it rejects a fractional / `NaN` / `Infinity` value
  /// by throwing rather than silently truncating it — a rounded id would
  /// point at a different row. `null` / absent stays `null`; a non-number
  /// (string, bool, …) throws a `TypeError` from the `as num` cast, matching
  /// the previous `as int?` behaviour.
  static int? _parseNullableId(dynamic value) {
    if (value == null) return null;
    final n = value as num;
    if (n is int) return n;
    if (n.isFinite && n == n.truncateToDouble()) return n.toInt();
    throw FormatException('API identifier must be a whole finite number: $n');
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

    int? parseIntField(dynamic v) => parseNum(v)?.round();

    return Garment(
      id: _parseNullableId(json['id']),
      garmentId: _parseNullableId(json['garment_id']),
      name: (json['name'] as String?) ?? '',
      brand: json['brand'] as String?,
      color: json['color'] as String?,
      fit: json['fit'] as String?,
      price: parseNum(json['price']),
      thickness: parseIntField(json['thickness']) ?? 0,
      formality: parseIntField(json['formality']) ?? 0,
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

  /// Builds a display-only Garment straight from a trip-plan item's own
  /// embedded fields (`TripSuitcaseItemResponse`/`TripOutfitItemResponse`,
  /// which return `image_url`/`category`/`name`/`color` inline) — trip pages
  /// no longer need to fetch the whole closet and cross-reference
  /// `garment_id` against it just to show a suitcase/day-outfit thumbnail.
  /// Note [json]'s own `id` is the trip item's row id, not the garment's —
  /// [id] here is deliberately set from `garment_id` instead, since that's
  /// what every other call site treats as "the garment's id". Fields the
  /// trip item response still doesn't carry (brand/fit/price/subCategory/...)
  /// stay at their defaults; nothing in the trip UI reads them for these
  /// garments.
  factory Garment.fromTripItemJson(Map<String, dynamic> json) {
    final garmentId = _parseNullableId(json['garment_id']);
    return Garment(
      id: garmentId,
      garmentId: garmentId,
      name: (json['name'] as String?) ?? '',
      color: json['color'] as String?,
      category: GarmentCategoryX.fromApiValue(json['category'] as String?),
      subCategory: '',
      uploadUrl: '',
      objectName: '',
      imageUrl: json['image_url'] as String?,
    );
  }

  /// `purchase_date` as the API expects it: a date-only `yyyy-MM-dd` string.
  /// The backend field is a Pydantic `date` and rejects a datetime carrying a
  /// non-zero time component, so every request path must send date-only —
  /// [toJson] (the PATCH payload) and `GarmentService.completeUpload` both
  /// serialize through this so the two can't drift apart.
  String? get purchaseDateApiValue =>
      purchaseDate?.toIso8601String().split('T').first;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'garment_id': garmentId,
      'name': name,
      'brand': brand,
      'color': color,
      'fit': fit,
      'price': price,
      'thickness': thickness,
      'formality': formality,
      'sub_category': subCategory,
      'category': category.apiValue,
      'purchase_date': purchaseDateApiValue,
      'upload_url': uploadUrl,
      'object_name': objectName,
      'image_url': imageUrl,
      'metadata': metadata,
    };
  }
}

/// Wraps the picker's chosen garment (or explicit "None") so a `null` pop
/// result — the sheet dismissed without a choice — can be told apart from
/// [garment] itself being `null` (the user explicitly picked "None").
class SelectGarmentResult {
  final Garment? garment;
  const SelectGarmentResult(this.garment);
}
