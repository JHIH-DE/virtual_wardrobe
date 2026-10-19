import 'package:flutter/widgets.dart';

abstract class AppDimens {
  // Outer padding of a full-page content grid.
  static const EdgeInsets pageGridPadding = EdgeInsets.fromLTRB(16, 16, 16, 24);

  // Gap between a card's header (title, or title+subtitle) and its body.
  static const double cardHeaderGap = 12;

  // Vertical gap between separate cards/major sections stacked on a page
  // (vs. [cardSpacing], for same-type items in a grid/list).
  static const double sectionSpacing = 16;

  // Gap between a details page's name heading and the first section below.
  static const double titleGap = 24;

  // Spacing between same-type cards in a grid, list or horizontal scroller.
  static const double cardSpacing = 12;

  static const double cardRadius = 16;

  // Outfit Card
  static const double outfitCardHeight = 235;

  // Corner radius of the full-width outfit photo on Outfit Details and
  // Today's Outfit.
  static const double outfitPhotoRadius = 20;

  // Garment Card
  static const double garmentCardWidth = 165;
  static const double garmentCardHeight = 230;
  static const double garmentCardInfoHeight = 70;

  // GarmentListCard. iOS CoreText renders NotoSansTC's CJK line box taller
  // (the text stack needs ~76px there), so keep >= 76 + the card's 2 * 8
  // vertical text padding.
  static const double garmentListCardHeight = 96;

  // An AppBar caps its leading and every `actions` child at this height —
  // also the tap-box size of an ActionDiscButton.
  static const double toolbarHeight = 56;

  // Measured height of a tappable form field (PickerField, DateDropdownField,
  // TappableFieldDecorator) so mixed text-field/picker rows line up.
  static const double tappableFieldHeight = 48;

  static const double iconSmallSize = 20;
  static const double iconMediumSize = 24;

  // A bare (disc-less) header-action glyph. AppToolBar's actions sit on an
  // ActionDisc and use ActionDisc.iconSize instead.
  static const double toolbarActionIconSize = 26;

  // Minimum hit-target edge; small glyphs keep their visual size but pad
  // their tappable area to this. 44 is the iOS HIG floor.
  static const double minTouchTarget = 44;

  // Matches [toolbarActionIconSize] so both sides of the camera header match.
  static const double backArrowIconSize = 26;

  // Bottom padding so a main tab's last row scrolls clear of the nav bar overlay.
  static const double mainNavBarClearance = 95;
  static const double bottomActionBtnClearance = 85;

  // ActionButton — the full-width pill CTA.
  static const double actionButtonHeight = 48;
  static const double actionButtonRadius = 100;
  static const double actionButtonBorderWidth = 1.5;
  static const double actionButtonIconGap = 8;
}
