import '../../../data/garment.dart';

/// The core garment slots of Create Outfit and Outfit Edit. [top] holds up
/// to [OutfitSelection.maxTops] garments; the rest hold one each.
enum OutfitSlot { top, outer, bottom, onePiece, shoes }

/// In-progress picks shared by Create Outfit and Outfit Edit — page state,
/// not a domain model. Immutable: every change returns a new selection, and
/// its lists can't be modified in place. Who picked what (locks, Match a
/// Look's picks) and which garments can be offered stay with each page.
class OutfitSelection {
  static const int maxTops = 2;
  static const int maxAccessories = 4;

  final List<Garment> tops;
  final Garment? outer;
  final Garment? bottom;
  final Garment? onePiece;
  final Garment? shoes;

  /// Accessories and socks in pick order, then one empty add-slot (null)
  /// until [maxAccessories] are picked.
  final List<Garment?> accessories;

  /// Copies [tops] and [accessories]; [accessories] gets the add-slot rule.
  OutfitSelection({
    List<Garment> tops = const [],
    this.outer,
    this.bottom,
    this.onePiece,
    this.shoes,
    Iterable<Garment?> accessories = const [],
  }) : tops = List.unmodifiable(tops),
       accessories = _normalized(accessories);

  /// The first [maxTops] tops, the first of each single slot and the first
  /// [maxAccessories] accessories / socks, in the order given.
  factory OutfitSelection.fromGarments(List<Garment> garments) {
    Garment? first(GarmentCategory c) =>
        garments.where((g) => g.category == c).firstOrNull;
    return OutfitSelection(
      tops: garments
          .where((g) => g.category == GarmentCategory.top)
          .take(maxTops)
          .toList(),
      outer: first(GarmentCategory.outer),
      bottom: first(GarmentCategory.bottom),
      onePiece: first(GarmentCategory.onePiece),
      shoes: first(GarmentCategory.shoes),
      accessories: garments.where(isAccessoryGarment).take(maxAccessories),
    );
  }

  static bool isAccessoryGarment(Garment g) =>
      g.category == GarmentCategory.accessory ||
      g.category == GarmentCategory.socks;

  static GarmentCategory categoryFor(OutfitSlot slot) {
    switch (slot) {
      case OutfitSlot.top:
        return GarmentCategory.top;
      case OutfitSlot.outer:
        return GarmentCategory.outer;
      case OutfitSlot.bottom:
        return GarmentCategory.bottom;
      case OutfitSlot.onePiece:
        return GarmentCategory.onePiece;
      case OutfitSlot.shoes:
        return GarmentCategory.shoes;
    }
  }

  /// Gaps closed, then one trailing add-slot while there's room.
  static List<Garment?> _normalized(Iterable<Garment?> accessories) {
    final picked = accessories.whereType<Garment>().toList();
    return List.unmodifiable([
      ...picked,
      if (picked.length < maxAccessories) null,
    ]);
  }

  List<Garment?> get _singles => [outer, bottom, onePiece, shoes];

  /// Tops first, then the single slots — the "Outfit Items" order. Core
  /// slots only; see [accessoryGarments].
  List<Garment> get garments => [...tops, ..._singles.whereType<Garment>()];

  List<Garment> get accessoryGarments =>
      accessories.whereType<Garment>().toList();

  Set<int> get accessoryIds =>
      accessoryGarments.map((g) => g.id).whereType<int>().toSet();

  OutfitSelection copyWith({
    List<Garment>? tops,
    Garment? outer,
    Garment? bottom,
    Garment? onePiece,
    Garment? shoes,
    bool clearOuter = false,
    bool clearBottom = false,
    bool clearOnePiece = false,
    bool clearShoes = false,
  }) {
    return OutfitSelection(
      tops: tops ?? this.tops,
      outer: clearOuter ? null : (outer ?? this.outer),
      bottom: clearBottom ? null : (bottom ?? this.bottom),
      onePiece: clearOnePiece ? null : (onePiece ?? this.onePiece),
      shoes: clearShoes ? null : (shoes ?? this.shoes),
      accessories: accessories,
    );
  }

  OutfitSelection _withAccessories(Iterable<Garment?> next) => OutfitSelection(
    tops: tops,
    outer: outer,
    bottom: bottom,
    onePiece: onePiece,
    shoes: shoes,
    accessories: next,
  );

  /// Single slots only; tops are indexed.
  Garment? garmentIn(OutfitSlot slot) {
    switch (slot) {
      case OutfitSlot.top:
        throw ArgumentError.value(slot, 'slot', 'tops are indexed');
      case OutfitSlot.outer:
        return outer;
      case OutfitSlot.bottom:
        return bottom;
      case OutfitSlot.onePiece:
        return onePiece;
      case OutfitSlot.shoes:
        return shoes;
    }
  }

  /// Single slots only; tops go through [withTop] or [withTopAt].
  OutfitSelection withSlot(OutfitSlot slot, Garment g) {
    switch (slot) {
      case OutfitSlot.top:
        throw ArgumentError.value(slot, 'slot', 'tops are indexed');
      case OutfitSlot.outer:
        return copyWith(outer: g);
      case OutfitSlot.bottom:
        return copyWith(bottom: g);
      case OutfitSlot.onePiece:
        return copyWith(onePiece: g);
      case OutfitSlot.shoes:
        return copyWith(shoes: g);
    }
  }

  OutfitSelection withoutSlot(OutfitSlot slot) {
    switch (slot) {
      case OutfitSlot.top:
        throw ArgumentError.value(slot, 'slot', 'tops are indexed');
      case OutfitSlot.outer:
        return copyWith(clearOuter: true);
      case OutfitSlot.bottom:
        return copyWith(clearBottom: true);
      case OutfitSlot.onePiece:
        return copyWith(clearOnePiece: true);
      case OutfitSlot.shoes:
        return copyWith(clearShoes: true);
    }
  }

  /// A top interchangeable with a worn one ([baseTopSlotKey], e.g. Polo
  /// over T-shirt) replaces it; otherwise it's added, or replaces the last
  /// top once [maxTops] are worn.
  OutfitSelection withTop(Garment g) {
    final next = [...tops];
    final same = next.indexWhere(
      (t) => baseTopSlotKey(t.subCategory) == baseTopSlotKey(g.subCategory),
    );
    if (same >= 0) {
      next[same] = g;
    } else if (next.length < maxTops) {
      next.add(g);
    } else {
      next[next.length - 1] = g;
    }
    return copyWith(tops: next);
  }

  OutfitSelection withTopAt(int index, Garment g) =>
      copyWith(tops: [...tops]..[index] = g);

  OutfitSelection withoutTopAt(int index) =>
      copyWith(tops: [...tops]..removeAt(index));

  OutfitSelection withAccessoryAt(int index, Garment g) =>
      _withAccessories([...accessories]..[index] = g);

  OutfitSelection withoutAccessoryAt(int index) =>
      _withAccessories([...accessories]..removeAt(index));

  /// [g] in the slot for its category: a top through [withTop], a single
  /// slot replaced, an accessory appended. Null when an accessory can't go
  /// in — [maxAccessories] already picked, or that garment already is.
  OutfitSelection? withGarment(Garment g) {
    switch (g.category) {
      case GarmentCategory.top:
        return withTop(g);
      case GarmentCategory.outer:
        return withSlot(OutfitSlot.outer, g);
      case GarmentCategory.bottom:
        return withSlot(OutfitSlot.bottom, g);
      case GarmentCategory.onePiece:
        return withSlot(OutfitSlot.onePiece, g);
      case GarmentCategory.shoes:
        return withSlot(OutfitSlot.shoes, g);
      case GarmentCategory.accessory:
      case GarmentCategory.socks:
        final filled = accessoryGarments;
        if (filled.length >= maxAccessories ||
            (g.id != null && accessoryIds.contains(g.id))) {
          return null;
        }
        return _withAccessories([...filled, g]);
    }
  }

  /// Whether [g] fits without replacing a garment already picked.
  bool hasRoomFor(Garment g) {
    switch (g.category) {
      case GarmentCategory.top:
        return tops.length < maxTops &&
            !tops.any(
              (t) =>
                  baseTopSlotKey(t.subCategory) ==
                  baseTopSlotKey(g.subCategory),
            );
      case GarmentCategory.outer:
        return outer == null;
      case GarmentCategory.bottom:
        return bottom == null;
      case GarmentCategory.onePiece:
        return onePiece == null;
      case GarmentCategory.shoes:
        return shoes == null;
      case GarmentCategory.accessory:
      case GarmentCategory.socks:
        // withGarment only appends accessories, never replaces one.
        return true;
    }
  }

  /// Only the garments whose ids are in [keepIds], each where it was.
  OutfitSelection keepingOnly(Set<int> keepIds) {
    bool kept(Garment? g) =>
        g != null && g.id != null && keepIds.contains(g.id);
    var next = copyWith(tops: tops.where(kept).toList());
    if (!kept(outer)) next = next.copyWith(clearOuter: true);
    if (!kept(bottom)) next = next.copyWith(clearBottom: true);
    if (!kept(onePiece)) next = next.copyWith(clearOnePiece: true);
    if (!kept(shoes)) next = next.copyWith(clearShoes: true);
    return next._withAccessories(accessories.where(kept));
  }
}
