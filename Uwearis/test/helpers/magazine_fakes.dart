import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:uwearis/core/providers/magazine_provider.dart';
import 'package:uwearis/data/magazine.dart';

/// An issue with one story for everyone, one for men and one for women.
/// No photos: `MagazineNetworkPhoto` would go to the network.
MagazineHome fakeMagazineHome(MagazineAudience audience) => MagazineHome(
  issue: MagazineIssue(
    id: 1,
    slug: 'issue-14',
    issueNumber: 14,
    title: 'The Outdoor Issue',
    subtitle: 'Outdoor style for everyday life.',
    publishedAt: DateTime(2026, 11, 20),
  ),
  stories: [
    const MagazineStorySummary(
      id: 1,
      issueId: 1,
      slug: 'one-blazer',
      title: 'One blazer, three ways',
      subtitle: 'A smarter way to dress for the week.',
    ),
    if (audience != MagazineAudience.women)
      const MagazineStorySummary(
        id: 2,
        issueId: 1,
        slug: 'rugged',
        title: 'Rugged meets relaxed',
        subtitle: 'Earthy tones and rugged boots for slow weekends.',
        audience: MagazineAudience.men,
      ),
    if (audience != MagazineAudience.men)
      const MagazineStorySummary(
        id: 3,
        issueId: 1,
        slug: 'soft-layers',
        title: 'Soft layers for the city',
        subtitle: 'Knits and long coats for cool evenings.',
        audience: MagazineAudience.women,
      ),
  ],
);

/// Serves [home] (default: [fakeMagazineHome]) instead of the backend.
Override fakeMagazineHomeOverride([
  MagazineHome Function(MagazineAudience audience) home = fakeMagazineHome,
]) => magazineHomeProvider.overrideWith((ref, key) async => home(key.audience));
