import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/home/home_getting_started_view.dart';

import '../helpers/widget_harness.dart';

void main() {
  testWidgets(
    'the whole checklist (About You, My Virtual Model, Top, Bottom, Shoes, '
    'Create Outfit) is always visible in one card, with only the done rows '
    'checked, and the CTA still reads Get Started before About You is done',
    (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: HomeGettingStartedView(
            hasAboutYou: false,
            hasProfilePhoto: true,
            hasFullBodyPhoto: true,
            hasTop: false,
            hasBottom: false,
            hasShoes: false,
            onGetStarted: () {},
            onAddClothing: () {},
            onCreateOutfit: () {},
          ),
        ),
      );

      expect(find.text('Welcome to Uwearis'), findsOneWidget);
      expect(find.text('About You'), findsOneWidget);
      expect(find.text('My Virtual Model'), findsOneWidget);
      expect(find.text('Top'), findsOneWidget);
      expect(find.text('Bottom'), findsOneWidget);
      expect(find.text('Shoes'), findsOneWidget);
      // My Virtual Model (both photos already set) is the only done row.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(5));
      // About You — the checklist's first row — isn't done yet, so the CTA
      // is still "Get Started", not "Next".
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Next'), findsNothing);
    },
  );

  testWidgets(
    'once About You is done the CTA switches to Next, even though My '
    'Virtual Model is still pending, and tapping it opens the profile '
    'step\'s first sub-step',
    (tester) async {
      var opened = false;
      await pumpApp(
        tester,
        Scaffold(
          body: HomeGettingStartedView(
            hasAboutYou: true,
            hasProfilePhoto: false,
            hasFullBodyPhoto: false,
            hasTop: false,
            hasBottom: false,
            hasShoes: false,
            onGetStarted: () => opened = true,
            onAddClothing: () {},
            onCreateOutfit: () {},
          ),
        ),
      );

      // About You done; everything else (including Create Outfit) pending.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(5));
      expect(find.text('Get Started'), findsNothing);
      expect(find.text('Next'), findsOneWidget);

      // The label says "Next", but the profile step still isn't done, so it
      // must still open the profile step's first sub-step.
      await tester.tap(find.text('Next'));
      expect(opened, isTrue);
    },
  );

  testWidgets(
    'only one of the two reference photos done still keeps My Virtual '
    'Model pending — it needs both — while the CTA stays Next since About '
    'You is already done',
    (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: HomeGettingStartedView(
            hasAboutYou: true,
            hasProfilePhoto: true,
            hasFullBodyPhoto: false,
            hasTop: false,
            hasBottom: false,
            hasShoes: false,
            onGetStarted: () {},
            onAddClothing: () {},
            onCreateOutfit: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(5));
      expect(find.text('Next'), findsOneWidget);
    },
  );

  testWidgets(
    'profile done but a closet missing Shoes keeps the CTA reading Next '
    '(About You already done), which still opens the existing add-clothing '
    'flow, with Top/Bottom already checked',
    (tester) async {
      var addClothingTapped = false;
      await pumpApp(
        tester,
        Scaffold(
          body: HomeGettingStartedView(
            hasAboutYou: true,
            hasProfilePhoto: true,
            hasFullBodyPhoto: true,
            hasTop: true,
            hasBottom: true,
            hasShoes: false,
            onGetStarted: () {},
            onAddClothing: () => addClothingTapped = true,
            onCreateOutfit: () {},
          ),
        ),
      );

      // About You, My Virtual Model, Top, Bottom done; Shoes and Create
      // Outfit still pending.
      expect(find.byIcon(Icons.check_circle), findsNWidgets(4));
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
      expect(find.text('Get Started'), findsNothing);
      expect(find.text('Next'), findsOneWidget);

      await tester.tap(find.text('Next'));
      expect(addClothingTapped, isTrue);
    },
  );

  testWidgets(
    'profile done and an empty closet leaves Top/Bottom/Shoes and Create '
    'Outfit all pending, with the CTA reading Next',
    (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: HomeGettingStartedView(
            hasAboutYou: true,
            hasProfilePhoto: true,
            hasFullBodyPhoto: true,
            hasTop: false,
            hasBottom: false,
            hasShoes: false,
            onGetStarted: () {},
            onAddClothing: () {},
            onCreateOutfit: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(4));
      expect(find.text('Next'), findsOneWidget);
    },
  );

  testWidgets(
    'profile and a full Top/Bottom/Shoes closet done still reads Next on '
    'the CTA, which now opens the existing add-outfit flow',
    (tester) async {
      var createOutfitTapped = false;
      await pumpApp(
        tester,
        Scaffold(
          body: HomeGettingStartedView(
            hasAboutYou: true,
            hasProfilePhoto: true,
            hasFullBodyPhoto: true,
            hasTop: true,
            hasBottom: true,
            hasShoes: true,
            onGetStarted: () {},
            onAddClothing: () {},
            onCreateOutfit: () => createOutfitTapped = true,
          ),
        ),
      );

      // Every checklist row done except Create Outfit's own — it never
      // shows as checked (see HomeGettingStartedView's doc comment).
      expect(find.byIcon(Icons.check_circle), findsNWidgets(5));
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      // "Create Outfit" only labels the checklist row now — the CTA itself
      // reads "Next".
      expect(find.text('Create Outfit'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      await tester.tap(find.text('Next'));
      expect(createOutfitTapped, isTrue);
    },
  );
}
