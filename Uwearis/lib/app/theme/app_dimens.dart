import 'package:flutter/widgets.dart';

abstract class AppDimens {
  // Standard page-level grid padding — a plain content grid's outer
  // padding (Select Garment/Accessory, Trip Outfit Selection, ...). Kept
  // as one constant so every full-page grid in the app uses the same
  // inset instead of each screen repeating the same literal.
  static const EdgeInsets pageGridPadding = EdgeInsets.fromLTRB(16, 16, 16, 24);

  // Standard gap between cards — grid cross/main axis spacing, the space
  // between successive cards in a vertical list, and horizontal-scroller
  // separators (GarmentCard, OutfitCard, TripCard, GarmentListCard,
  // background cards, style cards, ...). Kept as one constant so every card grid/list
  // in the app stays visually consistent instead of each screen picking
  // its own value.
  static const double cardSpacing = 12;

  // Gap between a card's header block (title, or title+subtitle) and the
  // body content below it — AppListCard, UwearisInsightCard, and every
  // page-level card with its own title (Style Taste's radar/profile cards,
  // Daily Outfit Plan, tryon_profile_page's reference sections, ...). Distinct
  // from [cardSpacing]'s "between separate cards" role.
  static const double cardHeaderGap = 12;

  // Vertical gap between separate cards/major sections stacked on a page
  // (as opposed to [cardSpacing], which is for same-type items in a
  // grid/list). Used between e.g. a page's insight card, suitcase card,
  // and day-plan card.
  static const double sectionSpacing = 16;

  // Standard corner radius for cards (GarmentCard, OutfitCard, TripCard,
  // GarmentListCard, AppListCard, UwearisInsightCard, TripDayCard, ...) — kept
  // as one constant so every card in the app reads as the same shape
  // instead of each one picking its own radius.
  static const double cardRadius = 16;

  // Outfit Card
  static const double outfitCardHeight = 235;

  // Garment Card
  static const double garmentCardWidth = 165;
  static const double garmentCardHeight = 230;
  static const double garmentCardInfoHeight = 70;

  // Shorter than Material's default kToolbarHeight (56) for a more compact
  // AppToolBar, but 48 rather than [minTouchTarget]'s 44: an AppBar caps
  // its leading and every `actions` child at this height, and the back
  // button / "⋮" menu should each clear a full 48x48 touch target.
  static const double toolbarHeight = 48;

  // Measured height of a tappable form field (PickerField, DateDropdownField,
  // TappableFieldDecorator) so mixed text-field/picker rows line up.
  static const double tappableFieldHeight = 48;

  static const double iconSmallSize = 20;
  static const double iconMediumSize = 24;

  // AppToolBar action-slot glyphs — the "⋮" overflow menu, the filter
  // button, and the image-asset actions (settings gear, suitcase "+").
  // Matched to [backArrowIconSize] so every icon on the bar (both sides)
  // reads as one size. The action IconButtons take zero padding + a 44px
  // box so their default 8px padding doesn't clamp the glyph or shrink the
  // hit area.
  static const double toolbarActionIconSize = 26;

  // Minimum comfortable hit-target edge (logical px) for an interactive
  // element. A small glyph / chip / badge keeps its smaller *visual* size
  // but should expand its tappable area (transparent padding / a
  // constraint) to at least this. 44 is the iOS HIG floor; 48 is the
  // cross-platform target where layout allows.
  static const double minTouchTarget = 44;

  // AppToolBar's back-arrow glyph (a Material Icon). Matches
  // [toolbarActionIconSize] so both sides of the bar render at one size.
  static const double backArrowIconSize = 26;

  // Extra bottom padding for scrollable lists/grids on the main tabs, so the
  // last row can scroll clear of the floating nav bar overlay instead of
  // being hidden behind it.
  static const double floatingNavBarClearance = 95;
  static const double bottomActionBtnClearance = 85;
}
