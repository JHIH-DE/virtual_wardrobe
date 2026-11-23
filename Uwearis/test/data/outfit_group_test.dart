import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/data/outfit_group.dart';

Map<String, dynamic> _outfit(int id) => {
  'outfit_id': id,
  'group_id': 7,
  'result_image_url': '',
};

void main() {
  test('fromJson keeps every version and the group fields', () {
    final g = OutfitGroup.fromJson({
      'group_id': 7,
      'type': 'trip',
      'name': 'Weekend',
      'cover_outfit_id': 12,
      'outfits': [_outfit(11), _outfit(12)],
    });
    expect(g.groupId, 7);
    expect(g.type, OutfitGroupType.trip);
    expect(g.name, 'Weekend');
    expect(g.versions.map((o) => o.id), [11, 12]);
    expect(g.versionCount, 2);
    expect(g.cover!.id, 12);
  });

  test('cover falls back to the lowest id, and is null with no versions', () {
    final g = OutfitGroup.fromJson({
      'group_id': 7,
      'cover_outfit_id': 99,
      'outfits': [_outfit(12), _outfit(11)],
    });
    expect(g.cover!.id, 11);
    expect(OutfitGroup.fromJson({'group_id': 7}).cover, isNull);
  });

  test('the passed groupId stands in when the body has none', () {
    expect(OutfitGroup.fromJson(const {}, groupId: 5).groupId, 5);
    expect(OutfitGroup.fromJson({'group_id': 7}, groupId: 5).groupId, 7);
  });
}
