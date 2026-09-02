import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/match_a_look.dart';

void main() {
  group('MatchALookRole', () {
    test('apiValue round-trips through MatchALookRoleX.fromApiValue', () {
      for (final role in MatchALookRole.values) {
        expect(MatchALookRoleX.fromApiValue(role.apiValue), role);
      }
    });

    test('multi-word roles map to snake_case wire values', () {
      expect(MatchALookRole.midLayer.apiValue, 'mid_layer');
      expect(MatchALookRole.onePiece.apiValue, 'one_piece');
    });

    test('fromApiValue returns null for an unrecognized/missing value', () {
      expect(MatchALookRoleX.fromApiValue('hat'), isNull);
      expect(MatchALookRoleX.fromApiValue(null), isNull);
    });
  });

  group('MatchStatusX.fromApiValue', () {
    test('parses every known status', () {
      expect(MatchStatusX.fromApiValue('strong_match'), MatchStatus.strongMatch);
      expect(MatchStatusX.fromApiValue('close_match'), MatchStatus.closeMatch);
      expect(MatchStatusX.fromApiValue('no_close_match'), MatchStatus.noCloseMatch);
    });

    test('falls back to notInReference for an unrecognized/missing value', () {
      expect(MatchStatusX.fromApiValue('unknown'), MatchStatus.notInReference);
      expect(MatchStatusX.fromApiValue(null), MatchStatus.notInReference);
    });
  });

  group('RoleAlternative.fromJson', () {
    test('parses garmentId and rank', () {
      final alt = RoleAlternative.fromJson({'garment_id': 12, 'rank': 1});
      expect(alt.garmentId, 12);
      expect(alt.rank, 1);
    });

    test('parses a float garment_id/rank', () {
      final alt = RoleAlternative.fromJson({'garment_id': 12.0, 'rank': 1.0});
      expect(alt.garmentId, 12);
      expect(alt.rank, 1);
    });

    // A malformed entry must default rather than throw — one bad alternative
    // would otherwise blow up the whole match-result parse.
    test('defaults to 0 when garment_id / rank are missing', () {
      final alt = RoleAlternative.fromJson({});
      expect(alt.garmentId, 0);
      expect(alt.rank, 0);
    });
  });

  group('RoleMatch', () {
    test('fromJson parses a fully-populated payload', () {
      final match = RoleMatch.fromJson({
        'role': 'top',
        'reference_present': true,
        'required': true,
        'importance': 'high',
        'match_status': 'strong_match',
        'selected_garment_id': 5,
        'alternatives': [
          {'garment_id': 5, 'rank': 1},
          {'garment_id': 9, 'rank': 2},
        ],
      });

      expect(match.role, MatchALookRole.top);
      expect(match.referencePresent, isTrue);
      expect(match.required, isTrue);
      expect(match.importance, 'high');
      expect(match.matchStatus, MatchStatus.strongMatch);
      expect(match.selectedGarmentId, 5);
      expect(match.rankedGarmentIds, [5, 9]);
      expect(match.matched, isTrue);
    });

    test('defaults role to accessory and booleans to false when missing', () {
      final match = RoleMatch.fromJson({});
      expect(match.role, MatchALookRole.accessory);
      expect(match.referencePresent, isFalse);
      expect(match.required, isFalse);
      expect(match.selectedGarmentId, isNull);
      expect(match.alternatives, isEmpty);
    });

    test('matched is true for strong or close match, false otherwise', () {
      MatchStatus statusOf(RoleMatch m) => m.matchStatus;
      final strong = RoleMatch.fromJson({'match_status': 'strong_match'});
      final close = RoleMatch.fromJson({'match_status': 'close_match'});
      final none = RoleMatch.fromJson({'match_status': 'no_close_match'});
      final absent = RoleMatch.fromJson({'match_status': null});

      expect(strong.matched, isTrue);
      expect(close.matched, isTrue);
      expect(none.matched, isFalse);
      expect(absent.matched, isFalse);
      // Sanity check the fixtures actually exercise distinct statuses.
      expect({statusOf(strong), statusOf(close), statusOf(none), statusOf(absent)}, hasLength(4));
    });
  });

  group('MatchALookSummary.fromJson', () {
    test('parses a populated payload', () {
      final summary = MatchALookSummary.fromJson({
        'matched_roles': 5,
        'unmatched_roles': 2,
        'missing_required_roles': ['bottom', 'shoes'],
      });
      expect(summary.matchedRoles, 5);
      expect(summary.unmatchedRoles, 2);
      expect(summary.missingRequiredRoles, ['bottom', 'shoes']);
    });

    test('defaults to all-zero/empty when the summary key itself is null', () {
      final summary = MatchALookSummary.fromJson(null);
      expect(summary.matchedRoles, 0);
      expect(summary.unmatchedRoles, 0);
      expect(summary.missingRequiredRoles, isEmpty);
    });
  });

  group('MatchALookResult.fromJson', () {
    test('parses roles, summary, and keys garments by id', () {
      final result = MatchALookResult.fromJson({
        'reference_id': 100,
        'roles': [
          {'role': 'top', 'match_status': 'strong_match', 'selected_garment_id': 1},
          {'role': 'bottom', 'match_status': 'no_close_match'},
        ],
        'summary': {'matched_roles': 1, 'unmatched_roles': 1, 'missing_required_roles': []},
        'garments': [
          {'id': 1, 'name': 'White Tee', 'category': 'Top'},
          {'id': 2, 'name': 'Blue Jeans', 'category': 'Bottom'},
        ],
      });

      expect(result.referenceId, 100);
      expect(result.roles, hasLength(2));
      expect(result.summary.matchedRoles, 1);
      expect(result.garments, hasLength(2));
      expect(result.garments[1]!.name, 'White Tee');
      expect(result.garments[2]!.name, 'Blue Jeans');
    });

    test('roleFor finds the matching role, or null if absent', () {
      final result = MatchALookResult.fromJson({
        'reference_id': 1,
        'roles': [
          {'role': 'shoes', 'match_status': 'strong_match'},
        ],
      });

      expect(result.roleFor(MatchALookRole.shoes), isNotNull);
      expect(result.roleFor(MatchALookRole.outer), isNull);
    });

    test('skips a garment entry with no id rather than throwing', () {
      final result = MatchALookResult.fromJson({
        'reference_id': 1,
        'garments': [
          {'name': 'No Id Garment', 'category': 'Top'},
        ],
      });
      expect(result.garments, isEmpty);
    });

    test('defaults referenceId/roles/garments when missing', () {
      final result = MatchALookResult.fromJson({});
      expect(result.referenceId, 0);
      expect(result.roles, isEmpty);
      expect(result.garments, isEmpty);
    });
  });
}
