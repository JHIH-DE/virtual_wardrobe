/// Per-garment try-on adjustments: garment id → adjustment key → option code.
/// Keys stay raw API strings so a key added on the backend still round-trips;
/// read them through [GarmentAdjustmentKeyApi.fromApiValue].
typedef GarmentAdjustments = Map<int, Map<String, int>>;

/// Backend `GarmentAdjustmentKey`.
enum GarmentAdjustmentKey {
  zipper,
  outerButtons,
  shirtButtons,
  hem,
  hood,
  bagCarry,
  pantCuff,
  sleeve,
  bootsPants,
  scarf,
  dressBelt,
  laces,
  cap,
}

extension GarmentAdjustmentKeyApi on GarmentAdjustmentKey {
  String get apiValue => switch (this) {
    GarmentAdjustmentKey.zipper => 'zipper',
    GarmentAdjustmentKey.outerButtons => 'outer_buttons',
    GarmentAdjustmentKey.shirtButtons => 'shirt_buttons',
    GarmentAdjustmentKey.hem => 'hem',
    GarmentAdjustmentKey.hood => 'hood',
    GarmentAdjustmentKey.bagCarry => 'bag_carry',
    GarmentAdjustmentKey.pantCuff => 'pant_cuff',
    GarmentAdjustmentKey.sleeve => 'sleeve',
    GarmentAdjustmentKey.bootsPants => 'boots_pants',
    GarmentAdjustmentKey.scarf => 'scarf',
    GarmentAdjustmentKey.dressBelt => 'dress_belt',
    GarmentAdjustmentKey.laces => 'laces',
    GarmentAdjustmentKey.cap => 'cap',
  };

  /// Null for a key this build doesn't know.
  static GarmentAdjustmentKey? fromApiValue(String? value) {
    for (final k in GarmentAdjustmentKey.values) {
      if (k.apiValue == value) return k;
    }
    return null;
  }
}

/// Options the backend offers that the app doesn't show (product choice):
/// shirt / outer buttons "partly unbuttoned" and hem "front tuck". The backend's
/// own default may still be one of them — Default is never sent as a code.
final Map<String, Set<int>> hiddenAdjustmentCodes = {
  GarmentAdjustmentKey.shirtButtons.apiValue: {2},
  GarmentAdjustmentKey.outerButtons.apiValue: {2},
  GarmentAdjustmentKey.hem.apiValue: {3},
};

/// `pant_cuff` 2 (cuffed) and `boots_pants` 2 (tucked into boots) can't be
/// sent together: generate answers 400.
const int pantCuffCuffed = 2;
const int bootsPantsTucked = 2;

/// One choice for an adjustment (e.g. zipper → "Fully zipped").
class AdjustmentOption {
  final int code;
  final String label;

  const AdjustmentOption({required this.code, required this.label});
}

/// One adjustment from `GET /outfit/adjustment-options`, labels already in
/// the user's locale. Codes aren't contiguous — never derive them locally.
/// The table's `default_code` isn't kept: the backend's real default depends
/// on the outfit, so the app never sends or shows it.
class AdjustmentDefinition {
  final String key;
  final String label;
  final List<AdjustmentOption> options;

  const AdjustmentDefinition({
    required this.key,
    required this.label,
    required this.options,
  });

  AdjustmentDefinition withoutCodes(Set<int> codes) => codes.isEmpty
      ? this
      : AdjustmentDefinition(
          key: key,
          label: label,
          options: [
            for (final o in options)
              if (!codes.contains(o.code)) o,
          ],
        );

  factory AdjustmentDefinition.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    return AdjustmentDefinition(
      key: (json['key'] as String?) ?? '',
      label: (json['label'] as String?) ?? '',
      options: [
        if (rawOptions is List)
          for (final o in rawOptions)
            if (o is Map<String, dynamic> && o['code'] is num)
              AdjustmentOption(
                code: (o['code'] as num).toInt(),
                label: (o['label'] as String?) ?? '',
              ),
      ],
    );
  }
}

List<Map<String, dynamic>> garmentAdjustmentsToJson(
  GarmentAdjustments adjustments,
) => [
  for (final e in adjustments.entries)
    if (e.value.isNotEmpty) {'garment_id': e.key, 'adjustments': e.value},
];
