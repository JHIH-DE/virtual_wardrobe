import 'package:flutter/material.dart';

/// Warm cream base, monochrome ink for actions/selection, black icons.
/// UI code uses these instead of raw `Color(0x...)` literals.
class AppColors {
  AppColors._();

  // Surfaces
  static const Color pageBackground = Color(0xFFEFECEB); // warm cream wash
  static const Color surface = Color(0xFFFFFFFF); // cards, toolbars, sheets
  static const Color placeholderSurface = Color(
    0xFFEDEAE3,
  ); // empty photo/avatar wells
  static const Color toolbarBackground = Color(0xFFEFECEB);
  static const Color interactiveArea = Color(0xFFF8F7F4);
  // CircleIconButton's glass disc: a lighter centre and darker edge so it
  // reads on both cream and white (a lighten-only fill vanishes on white).
  static const Color iconButtonFillCenter = Color(0x99FFFFFF); // white @60%
  static const Color iconButtonFillEdge = Color(0x143C3C43); // grey @8%
  static const Color iconButtonRim = Color(0x383C3C43); // grey @22%
  static const Color iconButtonSheen = Color(0xB3FFFFFF); // white @70%

  // Pressed-state fill (e.g. DialogOptionCard). #C6C0AB @ 36%.
  static const Color pressedOverlay = Color(0x5CC6C0AB);

  // Text & icons
  static const Color textPrimary = Color(0xFF262420);
  static const Color textSecondary = Color(0xFF6E6A62);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color hintText = Color(0xFF9C978C);
  static const Color icon = textPrimary;

  // Borders & dividers
  static const Color borderStrong = Color(0xFFB7AFA0);
  static const Color borderSubtle = Color(0xFFE7E3DA);
  static const Color dividerSubtle = Color(0xFFF1F1F1);

  // Brand — near-black for actions/selection
  static const Color primary = Color(0xFF1A1A1A);

  // Stands out from the monochrome palette (nav center button, primary
  // dialog actions).
  static const Color accent = Color(0xFF9966CC);

  // E.g. a selected filter chip's background.
  static const Color accentTint = Color(0x1F9966CC); // accent @12%

  // Attention outline (a highlighted AppListCard).
  static const Color accentOutline = Color(0x8C9966CC); // accent @55%

  // Social sign-in (fixed brand color, do not retint)
  static const Color facebook = Color(0xFF1877F2);

  // State
  static const Color error = Color(0xFFE4483F);

  // Filled-heart color when an outfit/garment is marked favorite
  static const Color favorite = Color(0xFFE53935);

  // Trip status dots (TripsPage's section headers)
  static const Color statusOngoing = Color(0xFF4CAF50);
  static const Color statusUpcoming = Color(0xFF4F7FFF);
  static const Color statusPast = Color(0xFF9E9E9E);

  // Settings' plan badge (UserTier) — metallic tones, each paired with a
  // text color that keeps >= 4.5:1 contrast on its own fill.
  static const Color tierGold = Color(0xFFE9C46A);
  static const Color tierGoldText = Color(0xFF5C4300);
  static const Color tierSilver = Color(0xFFD6D8DB);
  static const Color tierSilverText = Color(0xFF3F4347);
  static const Color tierBronze = Color(0xFFE2B48C);
  static const Color tierBronzeText = Color(0xFF5A3214);

  // AI-output call-out background (UwearisInsightCard).
  static const Color uwearisCardTint = Color(0xFFF3EFE6);
  static const LinearGradient uwearisGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surface, uwearisCardTint],
  );

  // CategoryTag (season/style/collection chips)
  static const Color tagBackground = Color(0xFFEFEAE2);
  static const Color tagText = Color(0xFF6F655A);

  // Style Profile pie chart: a validated 5-hue order (adjacent CVD ΔE >= 8).
  // Don't reorder or add a 6th — fold extra series into chartOther. Some
  // are below 3:1 on `surface`, so slices always need a text label.
  static const List<Color> chartCategorical = [
    Color(0xFF2A78D6), // blue
    Color(0xFFEB6834), // orange
    Color(0xFF1BAF7A), // aqua
    Color(0xFFEDA100), // yellow
    Color(0xFFE87BA4), // magenta
  ];
  // Neutral: the folded bucket isn't a single identity.
  static const Color chartOther = borderStrong;

  // Shared shadow/backdrop tiers
  static const Color shadowResting = Color(
    0x0F000000,
  ); // resting card shadow, black @6%
  static const Color overlaySubtle = Color(
    0x1F000000,
  ); // light overlay/shadow, black @12%
  static const Color surfaceTranslucent = Color(
    0xB3FFFFFF,
  ); // white @70%, e.g. a badge sitting on top of a photo
  static const Color scrimBackdrop = Color(
    0xA6000000,
  ); // full-screen dark backdrop, black @65%
  static const Color dividerOnDark = Color(
    0x26FFFFFF,
  ); // divider on dark surfaces (e.g. nav bar's quick-action menu), white @15%
  static const Color shadowSoft = Color(
    0x26000000,
  ); // soft drop shadow (e.g. a card corner badge), black @15%
  static const Color overlayMedium = Color(
    0x8A000000,
  ); // medium-strength overlay (e.g. an avatar's "edit photo" label bar), black @54%
  static const Color scrimMedium = Color(
    0x66000000,
  ); // medium-strength full-screen scrim (e.g. camera header bar), black @40%
  static const Color scrimStrong = Color(
    0x99000000,
  ); // strong full-screen scrim (e.g. camera cutout mask), black @60%
  static const Color surfaceTranslucentMedium = Color(
    0xA6FFFFFF,
  ); // white @65%, e.g. a badge sitting on top of a photo (slightly lighter than surfaceTranslucent)
  // Toolbar action disc, modelled on iOS 26's glass bar buttons.
  static const Color actionDiscFillCenter = Color(0x80FFFFFF); // white @50%
  static const Color actionDiscFillEdge = Color(0x10FFFFFF); // white @6%
  static const Color actionDiscRim = Color(
    0x4A3C3C43,
  ); // iOS separator grey @29%
  static const Color borderOnDark = Color(
    0x8AFFFFFF,
  ); // subtle border on dark buttons/dialogs, white @54%
  static const Color trueBlack = Color(
    0xFF000000,
  ); // pure opaque black — Material shadowColor, camera viewfinder backdrop/mask base
}
