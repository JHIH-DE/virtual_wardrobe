import 'garment.dart';

/// A garment role the Match a Look backend can detect in a reference photo
/// and try to match against the user's closet. Fixed set of 7, always
/// returned in this order by `POST /match_look/match` regardless of what
/// the reference photo actually contained.
enum MatchALookRole { top, midLayer, outer, bottom, onePiece, shoes, accessory }

extension MatchALookRoleX on MatchALookRole {
  String get apiValue {
    switch (this) {
      case MatchALookRole.top:
        return 'top';
      case MatchALookRole.midLayer:
        return 'mid_layer';
      case MatchALookRole.outer:
        return 'outer';
      case MatchALookRole.bottom:
        return 'bottom';
      case MatchALookRole.onePiece:
        return 'one_piece';
      case MatchALookRole.shoes:
        return 'shoes';
      case MatchALookRole.accessory:
        return 'accessory';
    }
  }

  static MatchALookRole? fromApiValue(String? value) {
    switch (value) {
      case 'top':
        return MatchALookRole.top;
      case 'mid_layer':
        return MatchALookRole.midLayer;
      case 'outer':
        return MatchALookRole.outer;
      case 'bottom':
        return MatchALookRole.bottom;
      case 'one_piece':
        return MatchALookRole.onePiece;
      case 'shoes':
        return MatchALookRole.shoes;
      case 'accessory':
        return MatchALookRole.accessory;
      default:
        return null;
    }
  }
}

/// How good a role's closet match is, per the backend's own confidence
/// judgment — the frontend never computes or displays a percentage, just
/// reflects this tier.
enum MatchStatus {
  /// Selected garment fits the role closely on every axis.
  strongMatch,

  /// Selected garment fits, but with some visible difference (color/
  /// silhouette/material).
  closeMatch,

  /// Reference shows this role, but nothing in the closet was close
  /// enough — [RoleMatch.selectedGarmentId] is null, but
  /// [RoleMatch.alternatives] may still be populated for manual browsing.
  noCloseMatch,

  /// Reference photo doesn't show this role at all.
  notInReference,
}

extension MatchStatusX on MatchStatus {
  static MatchStatus fromApiValue(String? value) {
    switch (value) {
      case 'strong_match':
        return MatchStatus.strongMatch;
      case 'close_match':
        return MatchStatus.closeMatch;
      case 'no_close_match':
        return MatchStatus.noCloseMatch;
      default:
        return MatchStatus.notInReference;
    }
  }
}

/// One ranked closet candidate for a role — `rank` starts at 1.
class RoleAlternative {
  final int garmentId;
  final int rank;

  const RoleAlternative({required this.garmentId, required this.rank});

  factory RoleAlternative.fromJson(Map<String, dynamic> json) {
    return RoleAlternative(
      // Defensive, like every other parse in this file: one malformed
      // alternative must not throw and kill the whole match result.
      garmentId: (json['garment_id'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One role's outcome from `POST /match_look/match`.
class RoleMatch {
  final MatchALookRole role;
  final bool referencePresent;
  final bool required;
  final String? importance;
  final MatchStatus matchStatus;
  final int? selectedGarmentId;

  /// Ranked closet candidates, #1 first (already includes
  /// [selectedGarmentId] at rank 1 when one exists) — up to 4. Populated
  /// even for [MatchStatus.noCloseMatch] so the user can still browse the
  /// closest-available options manually.
  final List<RoleAlternative> alternatives;

  const RoleMatch({
    required this.role,
    required this.referencePresent,
    required this.required,
    required this.importance,
    required this.matchStatus,
    required this.selectedGarmentId,
    required this.alternatives,
  });

  bool get matched =>
      matchStatus == MatchStatus.strongMatch ||
      matchStatus == MatchStatus.closeMatch;

  List<int> get rankedGarmentIds =>
      alternatives.map((a) => a.garmentId).toList();

  factory RoleMatch.fromJson(Map<String, dynamic> json) {
    return RoleMatch(
      role:
          MatchALookRoleX.fromApiValue(json['role'] as String?) ??
          MatchALookRole.accessory,
      referencePresent: (json['reference_present'] as bool?) ?? false,
      required: (json['required'] as bool?) ?? false,
      importance: json['importance'] as String?,
      matchStatus: MatchStatusX.fromApiValue(json['match_status'] as String?),
      selectedGarmentId: (json['selected_garment_id'] as num?)?.toInt(),
      alternatives:
          (json['alternatives'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(RoleAlternative.fromJson)
              .toList() ??
          const [],
    );
  }
}

class MatchALookSummary {
  final int matchedRoles;
  final int unmatchedRoles;
  final List<String> missingRequiredRoles;

  const MatchALookSummary({
    required this.matchedRoles,
    required this.unmatchedRoles,
    required this.missingRequiredRoles,
  });

  factory MatchALookSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const MatchALookSummary(
        matchedRoles: 0,
        unmatchedRoles: 0,
        missingRequiredRoles: [],
      );
    }
    return MatchALookSummary(
      matchedRoles: (json['matched_roles'] as num?)?.toInt() ?? 0,
      unmatchedRoles: (json['unmatched_roles'] as num?)?.toInt() ?? 0,
      missingRequiredRoles:
          (json['missing_required_roles'] as List?)
              ?.whereType<String>()
              .toList() ??
          const [],
    );
  }
}

/// `POST /match_look/match`'s full response — every role's outcome plus
/// the complete [Garment] objects for every id mentioned anywhere in
/// [roles] (already carrying fresh signed image URLs), so callers never
/// need to cross-reference the user's full closet fetch.
class MatchALookResult {
  final int referenceId;
  final List<RoleMatch> roles;
  final MatchALookSummary summary;
  final Map<int, Garment> garments;

  const MatchALookResult({
    required this.referenceId,
    required this.roles,
    required this.summary,
    required this.garments,
  });

  RoleMatch? roleFor(MatchALookRole role) {
    for (final r in roles) {
      if (r.role == role) return r;
    }
    return null;
  }

  factory MatchALookResult.fromJson(Map<String, dynamic> json) {
    final garments = <int, Garment>{};
    for (final g in (json['garments'] as List? ?? const [])) {
      if (g is Map<String, dynamic>) {
        final garment = Garment.fromJson(g);
        if (garment.id != null) garments[garment.id!] = garment;
      }
    }
    return MatchALookResult(
      referenceId: (json['reference_id'] as num?)?.toInt() ?? 0,
      roles:
          (json['roles'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(RoleMatch.fromJson)
              .toList() ??
          const [],
      summary: MatchALookSummary.fromJson(
        json['summary'] as Map<String, dynamic>?,
      ),
      garments: garments,
    );
  }
}
