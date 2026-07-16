import 'package:flutter/material.dart';

/// Warm cream base, monochrome ink for actions/selection, and uniformly
/// black icons. Every screen should pull colors from here; nothing else in
/// `lib/` should reference `Colors.*` or a raw `Color(0x...)` literal.
class AppColors {
  AppColors._();

  // Surfaces
  static const Color pageBackground = Color(0xFFEFECEB); // warm cream wash
  static const Color surface = Color(0xFFFFFFFF); // cards, toolbars, sheets
  static const Color placeholderSurface = Color(
    0xFFEDEAE3,
  ); // empty photo/avatar wells
  static const Color toolbarBackground = Color(0xFFFFFFFF);
  static const Color interactiveArea = Color(0xFFF8F7F4);

  // Text & icons
  static const Color textPrimary = Color(0xFF262420);
  static const Color textSecondary = Color(0xFF6E6A62);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color hintText = Color(0xFF9C978C);
  static const Color icon = textPrimary;

  // Borders & dividers
  static const Color borderStrong = Color(0xFFB7AFA0);
  static const Color borderSubtle = Color(0xFFE7E3DA);
  static const Color dividerStrong = Color(0xFF322F2A);
  static const Color dividerSubtle = Color(0xFFF1F1F1);
  static const Color placeholderIcon = Color(0xFFB6AFA2);

  // Brand — near-black for actions/selection
  static const Color primary = Color(0xFF1A1A1A);

  // Social sign-in (fixed brand colors, do not retint)
  static const Color facebook = Color(0xFF1877F2);
  static const Color google = Color(0xFF4285F4);

  // State
  static const Color error = Color(0xFFE4483F);
  static const Color success = Color(0xFF1FAE79);

  // Filled-heart color when a look/garment is marked favorite
  static const Color favorite = Color(0xFFE53935);

  // Trip status dots (TripPlannerPage's Ongoing/Upcoming/Past section headers)
  static const Color statusOngoing = Color(0xFF4CAF50);
  static const Color statusUpcoming = Color(0xFF4F7FFF);
  static const Color statusPast = Color(0xFF9E9E9E);

  // AppCard drop shadow (two-tone hard shadow)
  static const Color cardShadowTop = Color(0xFFE9E5DC);
  static const Color cardShadowBottom = Color(0xFFD6CFC0);

  // LumiInsightCard — the AI-output call-out's gradient background tint
  static const Color lumiCardTint = Color(0xFFF3EFE6);

  // Overlays — composed as base color + alpha so the opacity is explicit
  static const Color overlayScrim = Color(
    0x5C262420,
  ); // full-screen loading mask, ink @36%
  static const Color selectionTint = Color(
    0x5C1A1A1A,
  ); // selected-card highlight, primary @36%

  // Shared shadow/backdrop tiers (replaces ad hoc Colors.black.withOpacity(...) literals)
  static const Color shadowResting = Color(
    0x0F000000,
  ); // resting card shadow, black @6%
  static const Color overlaySubtle = Color(
    0x1F000000,
  ); // light overlay/shadow, black @12%
  static const Color scrimBackdrop = Color(
    0xA6000000,
  ); // full-screen dark backdrop, black @65%
}
