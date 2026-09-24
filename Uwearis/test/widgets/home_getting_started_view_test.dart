import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/home/home_getting_started_view.dart';

import '../helpers/widget_harness.dart';

void main() {
  testWidgets(
    'neither reference photo done shows both as pending and "Get Started" '
    'opens Try-On Profile',
    (tester) async {
      var opened = false;
      await pumpApp(
        tester,
        Scaffold(
          body: HomeGettingStartedView(
            hasProfilePhoto: false,
            hasFullBodyPhoto: false,
            hasTop: false,
            hasBottom: false,
            hasShoes: false,
            onOpenTryOnProfile: () => opened = true,
            onAddClothing: () {},
            onCreateOutfit: () {},
          ),
        ),
      );

      expect(find.text('Getting Started'), findsOneWidget);
      expect(find.text('Welcome to Uwearis'), findsOneWidget);
      expect(find.text('Profile Photo'), findsOneWidget);
      expect(find.text('Full-Body Photo'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
      // Not yet on the closet or first-outfit step.
      expect(find.text('Build your closet'), findsNothing);
      expect(find.text('Ready for your first look?'), findsNothing);

      await tester.tap(find.text('Get Started'));
      expect(opened, isTrue);
    },
  );

  testWidgets(
    'one reference photo done shows a mixed checklist, still on the profile '
    'step',
    (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: HomeGettingStartedView(
            hasProfilePhoto: true,
            hasFullBodyPhoto: false,
            hasTop: false,
            hasBottom: false,
            hasShoes: false,
            onOpenTryOnProfile: () {},
            onAddClothing: () {},
            onCreateOutfit: () {},
          ),
        ),
      );

      expect(find.text('Getting Started'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
    },
  );

  testWidgets(
    'both reference photos done but a closet missing shoes switches to the '
    'Build your closet step with a Top/Bottom/Shoes checklist, and Add '
    'Clothing opens the existing add-clothing flow',
    (tester) async {
      var addClothingTapped = false;
      await pumpApp(
        tester,
        Scaffold(
          body: HomeGettingStartedView(
            hasProfilePhoto: true,
            hasFullBodyPhoto: true,
            hasTop: true,
            hasBottom: true,
            hasShoes: false,
            onOpenTryOnProfile: () {},
            onAddClothing: () => addClothingTapped = true,
            onCreateOutfit: () {},
          ),
        ),
      );

      // The "Getting Started" divider stays regardless of which phase is
      // showing — it's placed above the phase branch, not inside any one
      // of them.
      expect(find.text('Getting Started'), findsOneWidget);
      expect(find.text('Build your closet'), findsOneWidget);
      expect(find.text('Profile Photo'), findsNothing);
      expect(find.text('Full-Body Photo'), findsNothing);
      expect(find.text('Get Started'), findsNothing);
      expect(find.text('Ready for your first look?'), findsNothing);

      // Top + Bottom already done, only Shoes still pending.
      expect(find.text('Top'), findsOneWidget);
      expect(find.text('Bottom'), findsOneWidget);
      expect(find.text('Shoes'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);

      await tester.tap(find.text('Add Clothing'));
      expect(addClothingTapped, isTrue);
    },
  );

  testWidgets(
    'photos done and closet empty shows the Top/Bottom/Shoes checklist all '
    'still pending',
    (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: HomeGettingStartedView(
            hasProfilePhoto: true,
            hasFullBodyPhoto: true,
            hasTop: false,
            hasBottom: false,
            hasShoes: false,
            onOpenTryOnProfile: () {},
            onAddClothing: () {},
            onCreateOutfit: () {},
          ),
        ),
      );

      expect(find.text('Build your closet'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(3));
    },
  );

  testWidgets(
    'photos and a full Top/Bottom/Shoes closet done switches to the final '
    '"Ready for your first look?" step, and Create Outfit opens the '
    'existing add-outfit flow',
    (tester) async {
      var createOutfitTapped = false;
      await pumpApp(
        tester,
        Scaffold(
          body: HomeGettingStartedView(
            hasProfilePhoto: true,
            hasFullBodyPhoto: true,
            hasTop: true,
            hasBottom: true,
            hasShoes: true,
            onOpenTryOnProfile: () {},
            onAddClothing: () {},
            onCreateOutfit: () => createOutfitTapped = true,
          ),
        ),
      );

      expect(find.text('Getting Started'), findsOneWidget);
      expect(find.text('Ready for your first look?'), findsOneWidget);
      expect(find.text('Create Outfit'), findsOneWidget);
      expect(find.text('Build your closet'), findsNothing);
      expect(find.text('Add Clothing'), findsNothing);

      await tester.tap(find.text('Create Outfit'));
      expect(createOutfitTapped, isTrue);
    },
  );
}
