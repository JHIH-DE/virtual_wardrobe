import 'garment.dart';

/// Backend `BagType`: the body's design, not how it's carried.
enum BagType {
  sacoche,
  tote,
  backpack,
  messenger,
  shoulderBag,
  crossbodyBag,
  handbag,
  clutch,
  waistBag,
  bucketBag,
  other,
}

/// How wide the strap looks (an AI classification, not a measurement).
enum StrapWidthClass { extraThin, thin, medium, wide, unknown }

String _snake(String camel) =>
    camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

T? _fromSnake<T extends Enum>(Object? value, List<T> values) {
  if (value is! String) return null;
  for (final v in values) {
    if (_snake(v.name) == value) return v;
  }
  return null;
}

extension BagTypeX on BagType {
  String get apiValue => _snake(name);
}

extension StrapWidthClassX on StrapWidthClass {
  String get apiValue => _snake(name);
}

/// Backend range for the user-measured body width
/// (`Settings.bag_body_width_cm_*`); anything outside is a 422.
const double bagBodyWidthMinCm = 3;
const double bagBodyWidthMaxCm = 150;

/// Mirrors the backend's `enums.is_bag()`: only these garments can have
/// [BagDetails] (a PATCH with them on anything else is a 400).
bool isBagGarment(GarmentCategory category, String subCategory) =>
    category == GarmentCategory.accessory &&
    RegExp(
      r'\bbags?\b|\btote|backpack|handbag|crossbody|sacoche|clutch|pouch|purse|satchel|messenger|wristlet|包',
    ).hasMatch(subCategory.toLowerCase());

/// `Garment.bag_details`. The classifications come from the AI and the user
/// may correct them; [bodyWidthCm] is only ever the user's own measurement
/// (the AI always leaves it null). Carrying isn't here: that's the
/// `bag_carry` try-on adjustment.
class BagDetails {
  final BagType? bagType;
  final double? bodyWidthCm;
  final StrapWidthClass? strapWidthClass;

  const BagDetails({this.bagType, this.bodyWidthCm, this.strapWidthClass});

  BagDetails copyWith({
    BagType? bagType,
    double? bodyWidthCm,
    StrapWidthClass? strapWidthClass,
    bool clearBodyWidthCm = false,
  }) {
    return BagDetails(
      bagType: bagType ?? this.bagType,
      bodyWidthCm: clearBodyWidthCm ? null : (bodyWidthCm ?? this.bodyWidthCm),
      strapWidthClass: strapWidthClass ?? this.strapWidthClass,
    );
  }

  factory BagDetails.fromJson(Map<String, dynamic> json) {
    final width = json['body_width_cm'];
    return BagDetails(
      bagType: _fromSnake(json['bag_type'], BagType.values),
      bodyWidthCm: width is num ? width.toDouble() : null,
      strapWidthClass: _fromSnake(
        json['strap_width_class'],
        StrapWidthClass.values,
      ),
    );
  }

  /// Every field is sent: PATCH merges field by field, so `null` clears.
  Map<String, dynamic> toJson() => {
    'bag_type': bagType?.apiValue,
    'body_width_cm': bodyWidthCm,
    'strap_width_class': strapWidthClass?.apiValue,
  };

  @override
  bool operator ==(Object other) =>
      other is BagDetails &&
      other.bagType == bagType &&
      other.bodyWidthCm == bodyWidthCm &&
      other.strapWidthClass == strapWidthClass;

  @override
  int get hashCode => Object.hash(bagType, bodyWidthCm, strapWidthClass);
}
