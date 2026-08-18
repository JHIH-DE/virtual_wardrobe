abstract class AppDimens {
  // Outfit Card
  static const double outfitCardHeight = 235;

  // Garment Card
  static const double garmentCardWidth = 165;
  static const double garmentCardHeight = 230;
  static const double garmentCardInfoHeight = 70;

  // Shorter than Material's default kToolbarHeight (56) for a more compact
  // AppToolBar across every page that uses it.
  static const double toolbarHeight = 40;

  static const double iconSmallSize = 20;
  static const double iconMediumSize = 24;
  static const double iconLargeSize = 64;

  // AppToolBar's default back-arrow glyph — bigger than iconMediumSize for
  // a more prominent tap target than a generic action icon.
  static const double backArrowIconSize = 48;

  // Extra bottom padding for scrollable lists/grids on the main tabs, so the
  // last row can scroll clear of the floating nav bar overlay instead of
  // being hidden behind it.
  static const double floatingNavBarClearance = 110;
  static const double bottomActionBtnClearance = 80;
}
