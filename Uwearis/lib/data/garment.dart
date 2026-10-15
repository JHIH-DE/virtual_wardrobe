import 'package:flutter/material.dart';

/// Stable cache key for a garment's photo; use it everywhere it's cached so
/// replacing the image busts every copy.
String garmentImageCacheKey(int garmentId) => 'garment-job-$garmentId';

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
  // Before `grey` so a "Charcoal Grey" from the AI resolves here, not to grey.
  charcoal,
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
      case GarmentColor.charcoal:
        return const Color(0xFF3F3F3F);
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

/// Ordered tight → loose; the details page's Fit picker lists it in order.
enum GarmentFit { skinny, slim, regular, relaxed, oversized }

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

/// Matches the backend's normalization: case, spaces, hyphens and
/// underscores don't matter ("a line" == "A-Line" == "A-line").
String _normalizeAttr(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');

T? _attrFromApiValue<T>(String? value, List<T> values, String Function(T) api) {
  if (value == null || value.isEmpty) return null;
  final key = _normalizeAttr(value);
  for (final v in values) {
    if (_normalizeAttr(api(v)) == key) return v;
  }
  return null;
}

enum GarmentSilhouette {
  straight,
  boxy,
  longline,
  cropped,
  cocoon,
  tapered,
  balloon,
  jogger,
  flared,
  pencil,
  aLine,
  pleated,
  shift,
  fitAndFlare,
}

extension GarmentSilhouetteX on GarmentSilhouette {
  String get apiValue {
    switch (this) {
      case GarmentSilhouette.aLine:
        return 'A-line';
      case GarmentSilhouette.fitAndFlare:
        return 'Fit-and-flare';
      default:
        return name[0].toUpperCase() + name.substring(1);
    }
  }

  static GarmentSilhouette? fromApiValue(String? value) =>
      _attrFromApiValue(value, GarmentSilhouette.values, (v) => v.apiValue);
}

/// Silhouettes the backend accepts per category. Bottom covers both the
/// trouser and skirt groups (`Flared` is shared).
const Map<GarmentCategory, List<GarmentSilhouette>>
garmentSilhouettesByCategory = {
  GarmentCategory.top: [
    GarmentSilhouette.straight,
    GarmentSilhouette.boxy,
    GarmentSilhouette.longline,
    GarmentSilhouette.cropped,
  ],
  GarmentCategory.outer: [
    GarmentSilhouette.straight,
    GarmentSilhouette.boxy,
    GarmentSilhouette.longline,
    GarmentSilhouette.cocoon,
  ],
  GarmentCategory.bottom: [
    GarmentSilhouette.straight,
    GarmentSilhouette.tapered,
    GarmentSilhouette.balloon,
    GarmentSilhouette.jogger,
    GarmentSilhouette.flared,
    GarmentSilhouette.pencil,
    GarmentSilhouette.aLine,
    GarmentSilhouette.pleated,
  ],
  GarmentCategory.onePiece: [
    GarmentSilhouette.straight,
    GarmentSilhouette.shift,
    GarmentSilhouette.aLine,
    GarmentSilhouette.fitAndFlare,
  ],
};

enum GarmentSleeveLength { sleeveless, short, threeQuarter, long }

extension GarmentSleeveLengthX on GarmentSleeveLength {
  String get apiValue {
    switch (this) {
      case GarmentSleeveLength.sleeveless:
        return 'Sleeveless';
      case GarmentSleeveLength.short:
        return 'Short';
      case GarmentSleeveLength.threeQuarter:
        return 'Three-quarter';
      case GarmentSleeveLength.long:
        return 'Long';
    }
  }

  static GarmentSleeveLength? fromApiValue(String? value) =>
      _attrFromApiValue(value, GarmentSleeveLength.values, (v) => v.apiValue);
}

const Set<GarmentCategory> garmentSleeveLengthCategories = {
  GarmentCategory.top,
  GarmentCategory.outer,
  GarmentCategory.onePiece,
};

enum GarmentCropLength {
  fullLength,
  nineLength,
  sevenLength,
  fiveLength,
  shorts,
}

extension GarmentCropLengthX on GarmentCropLength {
  String get apiValue {
    switch (this) {
      case GarmentCropLength.fullLength:
        return 'Full-length';
      case GarmentCropLength.nineLength:
        return 'Nine-length';
      case GarmentCropLength.sevenLength:
        return 'Seven-length';
      case GarmentCropLength.fiveLength:
        return 'Five-length';
      case GarmentCropLength.shorts:
        return 'Shorts';
    }
  }

  static GarmentCropLength? fromApiValue(String? value) =>
      _attrFromApiValue(value, GarmentCropLength.values, (v) => v.apiValue);
}

const Set<GarmentCategory> garmentCropLengthCategories = {
  GarmentCategory.bottom,
  GarmentCategory.onePiece,
};

/// Categories [GarmentFit] applies to (not shoes, socks or accessories).
const Set<GarmentCategory> garmentFitCategories = {
  GarmentCategory.top,
  GarmentCategory.bottom,
  GarmentCategory.outer,
  GarmentCategory.onePiece,
};

/// Exclusivity slot for an accessory's freeform `subCategory` ("Hat" and
/// "Cap" are both headwear). Only merges pairs known to collide.
String accessorySlotKey(String subCategory) {
  final normalized = subCategory.toLowerCase();
  const headwear = {'hat', 'cap'};
  if (headwear.contains(normalized)) return 'headwear';
  return normalized;
}

/// Base-layer slot for a top's `subCategory` ("T-shirt" and "Polo shirt"
/// replace each other instead of stacking like a mid layer would). Only
/// merges pairs known to collide.
String baseTopSlotKey(String subCategory) {
  final normalized = subCategory.toLowerCase();
  const baseTop = {'t-shirt', 'polo shirt'};
  if (baseTop.contains(normalized)) return 'base-top';
  return normalized;
}

class Garment {
  final int? id;
  final int? garmentId;
  final String name;
  final String? brand;
  final String? color;
  final String? fit;

  /// Raw API values. `""` means the category has no such concept (e.g. a
  /// shoe's sleeve length); `null` means applicable but not set.
  final String? silhouette;
  final String? sleeveLength;
  final String? cropLength;
  final double? price;
  final DateTime? purchaseDate;
  final String? imageUrl;
  final GarmentCategory category;
  final String subCategory;

  /// Backend scales are 1–5; 0 means unset and is omitted from PATCH. Not
  /// shown in the UI.
  final int thickness;
  final int formality;
  final String uploadUrl;
  final String objectName;
  final Map<String, dynamic>? metadata;
  final bool isFavorite;

  /// Soft-deleted: the backend keeps the row because an outfit/trip item
  /// still references it. See [ActiveGarmentsX.active].
  final bool isDeleted;

  const Garment({
    required this.name,
    required this.category,
    required this.subCategory,
    required this.uploadUrl,
    required this.objectName,
    this.thickness = 0,
    this.formality = 0,
    this.isFavorite = false,
    this.isDeleted = false,
    this.id,
    this.garmentId,
    this.brand,
    this.color,
    this.fit,
    this.silhouette,
    this.sleeveLength,
    this.cropLength,
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
    String? silhouette,
    String? sleeveLength,
    String? cropLength,
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
    bool? isDeleted,
    bool clearId = false,
    bool clearGarmentId = false,
    bool clearBrand = false,
    bool clearColor = false,
    bool clearFit = false,
    bool clearSilhouette = false,
    bool clearSleeveLength = false,
    bool clearCropLength = false,
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
      silhouette: clearSilhouette ? null : (silhouette ?? this.silhouette),
      sleeveLength: clearSleeveLength
          ? null
          : (sleeveLength ?? this.sleeveLength),
      cropLength: clearCropLength ? null : (cropLength ?? this.cropLength),
      price: clearPrice ? null : (price ?? this.price),
      purchaseDate: clearPurchaseDate
          ? null
          : (purchaseDate ?? this.purchaseDate),
      metadata: clearMetadata ? null : (metadata ?? this.metadata),
      isFavorite: isFavorite ?? this.isFavorite,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  /// Unlike other numeric fields, an id is never parsed from a string or
  /// rounded: a fractional id throws, since a rounded one would point at a
  /// different row.
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
      silhouette: json['silhouette'] as String?,
      sleeveLength: json['sleeve_length'] as String?,
      cropLength: json['crop_length'] as String?,
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
      isDeleted: (json['is_deleted'] as bool?) ?? false,
    );
  }

  /// Display-only Garment from a trip-plan item's embedded fields. The
  /// item's own `id` is its row id, so [id] comes from `garment_id`.
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

  /// Date-only `yyyy-MM-dd`: the backend's Pydantic `date` rejects a
  /// datetime with a non-zero time. Every request path must use this.
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
      'silhouette': silhouette,
      'sleeve_length': sleeveLength,
      'crop_length': cropLength,
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

/// Tells a dismissed picker (`null` pop) apart from an explicit "None"
/// ([garment] == null).
class SelectGarmentResult {
  final Garment? garment;
  const SelectGarmentResult(this.garment);
}

/// `garmentsProvider` includes soft-deleted garments. Use `.active` wherever
/// garments are browsed or offered for selection; not for resolving an
/// existing outfit's `garment_ids`, where deleted ones must still resolve.
extension ActiveGarmentsX on List<Garment> {
  List<Garment> get active => where((g) => !g.isDeleted).toList();
}
