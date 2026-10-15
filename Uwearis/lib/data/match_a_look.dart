import 'garment.dart';

/// A garment role Match a Look can detect. `POST /match_look/match` always
/// returns all 7, in this order, whatever the photo contained.
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

/// The backend's confidence tier; the app never computes a percentage.
enum MatchStatus {
  strongMatch,
  closeMatch,

  /// No selected garment, but [RoleMatch.alternatives] may still be set.
  noCloseMatch,
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
      // One malformed alternative must not kill the whole result.
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

  /// Up to 4, #1 first (includes [selectedGarmentId] at rank 1 when set).
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

/// [garments] holds every id mentioned in [roles], with fresh signed URLs,
/// so callers don't need the closet fetch.
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
