// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Uwearis';

  @override
  String get settings => 'Settings';

  @override
  String get account => 'Account';

  @override
  String get aiModel => 'Try-On Profile';

  @override
  String get aiModelDescription =>
      'Add reference photos to help Uwearis create more accurate try-ons.';

  @override
  String get faceReferenceLabel => 'Face Reference';

  @override
  String get faceReferenceComingSoon => 'Coming soon';

  @override
  String get bodyReferenceLabel => 'Body Reference';

  @override
  String get bodyMeasurementsLabel => 'Body Measurements';

  @override
  String get faceAppearanceSubtitle => 'Face, hair & facial features';

  @override
  String get bodyProportionsSubtitle => 'Body shape & proportions';

  @override
  String get changePhotoAction => 'Change photo';

  @override
  String get addPhotoAction => 'Add photo';

  @override
  String get aiModelReady => 'Ready · Face + Body Configured';

  @override
  String aiModelReferencesAdded(int count) {
    return '$count/2 References Added';
  }

  @override
  String get styleTaste => 'Style Taste';

  @override
  String get styleTasteDetailsLabel => 'Style Insights';

  @override
  String get styleTasteSummary =>
      'Uwearis learns how you like to put outfits together';

  @override
  String get styleTasteHeroSubtitle =>
      'Based on your saved outfits and feedback, Uwearis is learning your style taste.';

  @override
  String get styleTasteDimensionsInfoTitle => 'What these mean';

  @override
  String get styleTasteRadarCardTitle => 'Your Style Taste';

  @override
  String get styleTasteRadarCardSubtitle =>
      'A visual summary of your style preferences.';

  @override
  String get styleProfileCardTitle => 'Style Distribution';

  @override
  String get styleProfileCardSubtitle =>
      'How your outfits break down by style.';

  @override
  String get styleProfileOther => 'Other';

  @override
  String styleTasteAnalysisStats(int count, int favoriteCount) {
    return 'Analyzed $count outfits · $favoriteCount favorites';
  }

  @override
  String get lifestyle => 'Lifestyle';

  @override
  String get logout => 'Logout';

  @override
  String get language => 'Language';

  @override
  String get selectLanguageTitle => 'Select Language';

  @override
  String get languageSystemDefault => 'System Default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTraditionalChinese => '繁體中文';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get remove => 'Remove';

  @override
  String get rename => 'Rename';

  @override
  String get share => 'Share';

  @override
  String get delete => 'Delete';

  @override
  String get details => 'Details';

  @override
  String get renameOutfit => 'Rename Outfit';

  @override
  String get outfitNameLabel => 'Name of this outfit';

  @override
  String get createAnotherVersion => 'Create Another Version';

  @override
  String get addToMyOutfits => 'Add to My Outfits';

  @override
  String get selectOutfitGroupTitle => 'Add to Outfit';

  @override
  String get newOutfitGroup => 'New Outfit';

  @override
  String get customizationOptional => 'Accessories & Background';

  @override
  String get currentOutfitLabel => 'Current Outfit';

  @override
  String get accessoriesLabel => 'Accessories';

  @override
  String get optionalLabel => 'Optional';

  @override
  String get createOutfit => 'Create Outfit';

  @override
  String get createOutfitHint => 'Create another outfit using these garments';

  @override
  String get backgroundLabel => 'Background';

  @override
  String get noneLabel => 'None';

  @override
  String selectItemTitle(String item) {
    return 'Select $item';
  }

  @override
  String get notSelected => 'Not selected';

  @override
  String get loadingGarments => 'Loading Garments…';

  @override
  String get myCollection => 'My Collection';

  @override
  String get myOutfit => 'My Outfit';

  @override
  String get shareComingSoon => 'Share coming soon';

  @override
  String get failedToLoadImage => 'Failed to load image';

  @override
  String get failedToLoadGarments => 'Failed to load garments';

  @override
  String get deleteOutfitTitle => 'Delete Outfit';

  @override
  String get deleteOutfitConfirmation =>
      'Are you sure you want to delete this version?';

  @override
  String get deleteOutfitGroupConfirmation =>
      'This will also delete every other outfit generated together with it. This can\'t be undone.';

  @override
  String get deleteThisVersion => 'Delete Version';

  @override
  String createdOnDate(String date) {
    return 'Created $date';
  }

  @override
  String outfitTitle(String style) {
    return '$style Outfit';
  }

  @override
  String garmentsCount(int count) {
    return 'Garments ($count)';
  }

  @override
  String get styleMinimal => 'Minimal';

  @override
  String get styleClassic => 'Classic';

  @override
  String get styleStreetwear => 'Streetwear';

  @override
  String get styleSmartCasual => 'Smart Casual';

  @override
  String get styleAthleisure => 'Athleisure';

  @override
  String get styleVintage => 'Vintage';

  @override
  String get styleWorkwear => 'Workwear';

  @override
  String get stylePreppy => 'Preppy';

  @override
  String get styleBusiness => 'Business';

  @override
  String get styleTasteStyleBalanceTitle => 'Style Balance';

  @override
  String get styleTasteStyleBalanceLow => 'Consistent';

  @override
  String get styleTasteStyleBalanceHigh => 'Mixed';

  @override
  String get styleTasteStyleBalanceExplanation =>
      'Your preference for mixing different styles.';

  @override
  String get styleTasteColorPairingTitle => 'Color Pairing';

  @override
  String get styleTasteColorPairingLow => 'Tonal';

  @override
  String get styleTasteColorPairingHigh => 'Contrast';

  @override
  String get styleTasteColorPairingExplanation =>
      'Your preference for combining colors.';

  @override
  String get styleTasteFitPreferenceTitle => 'Fit Preference';

  @override
  String get styleTasteFitPreferenceLow => 'Fitted';

  @override
  String get styleTasteFitPreferenceHigh => 'Relaxed';

  @override
  String get styleTasteFitPreferenceExplanation =>
      'Your preferred clothing fit.';

  @override
  String get styleTasteLayeringTitle => 'Layering';

  @override
  String get styleTasteLayeringLow => 'Simple';

  @override
  String get styleTasteLayeringHigh => 'Layered';

  @override
  String get styleTasteLayeringExplanation =>
      'Your preference for layered looks.';

  @override
  String get styleTasteAccessoriesTitle => 'Accessories';

  @override
  String get styleTasteAccessoriesLow => 'Minimal';

  @override
  String get styleTasteAccessoriesHigh => 'Expressive';

  @override
  String get styleTasteAccessoriesExplanation =>
      'Your preference for using accessories.';

  @override
  String get navHome => 'Home';

  @override
  String get navCloset => 'Closet';

  @override
  String get navOutfits => 'Outfits';

  @override
  String get navTrips => 'Trips';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get quickActionAddClothing => 'New Clothing';

  @override
  String get quickActionAddOutfit => 'New Outfit';

  @override
  String get newTrip => 'New Trip';

  @override
  String get retry => 'Retry';

  @override
  String get aiTag => 'AI';

  @override
  String get matchALookTitle => 'Match a Look';

  @override
  String get matchALookSubtitle =>
      'Upload a photo and we\'ll find similar pieces from your closet.';

  @override
  String get matchingLookEllipsis => 'Matching your look...';

  @override
  String get matchALookFailed =>
      'Couldn\'t match that photo. Please try again.';

  @override
  String get matchALookNoPerson =>
      'We couldn\'t find a person in that photo. Try a different one.';

  @override
  String get matchALookMultiplePeople =>
      'That photo has more than one person in it. Try a photo with just you.';

  @override
  String get matchALookOutfitUnclear =>
      'We couldn\'t see the outfit clearly in that photo. Try a clearer, unobstructed shot.';

  @override
  String get matchALookInsufficientCloset =>
      'Add a few more pieces to your closet before using Match a Look.';

  @override
  String get noCloseMatch => 'No close match';

  @override
  String get referenceLookLabel => 'Reference Look';

  @override
  String piecesMatchedCount(int count) {
    return '$count pieces matched';
  }

  @override
  String get change => 'Change';

  @override
  String get removeReferenceLook => 'Remove Reference Look';

  @override
  String get editPhoto => 'Edit Photo';

  @override
  String noOptionsAvailable(String label) {
    return 'No $label available';
  }

  @override
  String get editTripName => 'Edit Name';

  @override
  String get editDestinations => 'Edit Destinations';

  @override
  String get enterTripName => 'Enter trip name';

  @override
  String get editTripActivities => 'Edit Activities';

  @override
  String get deleteTrip => 'Delete Trip';

  @override
  String get deleteTripConfirmation =>
      'Are you sure you want to delete this trip?';

  @override
  String get viewPlan => 'View Plan';

  @override
  String get tripNameLabel => 'Trip Name';

  @override
  String get create => 'Create';

  @override
  String get fillAllFieldsError => 'Please fill all fields';

  @override
  String get regenerate => 'Regenerate';

  @override
  String get setAsCover => 'Set as Cover';

  @override
  String get letUwearisPlanOutfits => 'Let Uwearis Plan Your Trip';

  @override
  String get letUwearisPlanOutfitsHint =>
      'Uwearis will build an outfit for every day using what\'s in your suitcase.';

  @override
  String get generateTripPlan => 'Generate Trip Plan';

  @override
  String get regenerateTripPlan => 'Regenerate Trip Plan';

  @override
  String get regeneratePlanTitle => 'Regenerate outfit plan?';

  @override
  String get regeneratePlanBody =>
      'This will replace every day\'s current outfit, including any you\'ve adjusted by hand.';

  @override
  String get failedToGeneratePlan => 'Failed to generate outfit plan';

  @override
  String get generatingPlanEllipsis => 'Planning your outfits…';

  @override
  String get failedToUpdateDayOutfit => 'Failed to update outfit';

  @override
  String get failedToGenerateOutfit => 'Failed to generate outfit';

  @override
  String get regenerateOutfit => 'Regenerate Outfit';

  @override
  String get changeGarments => 'Change Garments';

  @override
  String get noOutfitPlannedYetTitle => 'No outfit planned yet';

  @override
  String get noOutfitPlannedYetHint =>
      'Generate your trip plan to assign clothes for this day.';

  @override
  String get insufficientSuitcaseTitle => 'Not Enough in Your Suitcase';

  @override
  String get insufficientSuitcaseBody =>
      'Uwearis needs at least one top (or one-piece) and one bottom to plan outfits. Add a few more pieces to your suitcase first.';

  @override
  String get goToSuitcase => 'Go to Suitcase';

  @override
  String missingFromSuitcaseCount(int count) {
    return '$count items aren\'t packed yet.';
  }

  @override
  String get addToSuitcase => 'Add to Suitcase';

  @override
  String get loading => 'Loading…';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get generatingOutfitEllipsis => 'Generating your outfit…';

  @override
  String get noOutfitImageYet => 'No outfit image yet';

  @override
  String get generateOutfit => 'Generate Outfit';

  @override
  String get selectDates => 'Select Dates';

  @override
  String get startDatePlaceholder => 'Start Date';

  @override
  String get endDatePlaceholder => 'End Date';

  @override
  String get booked => 'Booked';

  @override
  String get selected => 'Selected';

  @override
  String get confirm => 'Confirm';

  @override
  String get addLocation => 'Add Location';

  @override
  String get addClothingPrompt => 'How would you like to add a new clothing?';

  @override
  String get camera => 'Camera';

  @override
  String get photoAlbum => 'Photo Album';

  @override
  String get back => 'Back';

  @override
  String outfitFallbackTitle(int id) {
    return 'Outfit #$id';
  }

  @override
  String get failedToLoad => 'Failed to Load';

  @override
  String get noImage => 'No Image';

  @override
  String get tripActivityOutdoor => 'Outdoor';

  @override
  String get tripActivityBusiness => 'Business';

  @override
  String get tripActivityFormalOccasion => 'Formal Occasion';

  @override
  String get tripActivityWaterActivities => 'Water Activities';

  @override
  String get categoryTop => 'Top';

  @override
  String get categoryBottom => 'Bottom';

  @override
  String get categoryOuter => 'Outer';

  @override
  String get categoryOnePiece => 'One-piece';

  @override
  String get categorySocks => 'Socks';

  @override
  String get categoryShoes => 'Shoes';

  @override
  String get categoryAccessory => 'Accessory';

  @override
  String get categoryTopPlural => 'Tops';

  @override
  String get categoryBottomPlural => 'Bottoms';

  @override
  String get categoryOuterPlural => 'Outers';

  @override
  String get categoryOnePiecePlural => 'One-pieces';

  @override
  String get categoryShoesPlural => 'Shoes';

  @override
  String get colorBlack => 'Black';

  @override
  String get colorWhite => 'White';

  @override
  String get colorGrey => 'Grey';

  @override
  String get colorBeige => 'Beige';

  @override
  String get colorCream => 'Cream';

  @override
  String get colorBrown => 'Brown';

  @override
  String get colorNavy => 'Navy';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorOlive => 'Olive';

  @override
  String get colorKhaki => 'Khaki';

  @override
  String get colorRed => 'Red';

  @override
  String get colorBurgundy => 'Burgundy';

  @override
  String get colorYellow => 'Yellow';

  @override
  String get colorOrange => 'Orange';

  @override
  String get colorPink => 'Pink';

  @override
  String get colorPurple => 'Purple';

  @override
  String get renameGarment => 'Rename Garment';

  @override
  String get deleteGarment => 'Delete Garment';

  @override
  String get deleteGarmentConfirmation =>
      'Are you sure you want to delete this garment?';

  @override
  String deleteFailedPrefix(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get unsavedChangesTitle => 'You have unsaved changes';

  @override
  String get unsavedChangesBody =>
      'If you leave this page, your changes will be lost.';

  @override
  String get dontSave => 'Don\'t Save';

  @override
  String get addToCloset => 'Add to Closet';

  @override
  String get clothingAdded => 'Clothing Added';

  @override
  String get recentlyAdded => 'Recently Added';

  @override
  String garmentPairsWellWith(String subCategory, int count) {
    return 'This $subCategory pairs well with $count items in your closet.';
  }

  @override
  String garmentPairsWellWithGeneric(int count) {
    return 'Pairs well with $count items in your closet.';
  }

  @override
  String get scoreTierExcellent => 'Excellent Match';

  @override
  String get scoreTierHighlyVersatile => 'Highly Versatile';

  @override
  String get scoreTierGoodMatch => 'Good Match';

  @override
  String get scoreTierLimitedMatch => 'Limited Match';

  @override
  String get scoreTierHardToStyle => 'Hard to Style';

  @override
  String get clothingNameLabel => 'Name';

  @override
  String get nameTheClothingHint => 'Name the clothing';

  @override
  String get pleaseEnterNameError => 'Please enter name';

  @override
  String get clothingCategoryLabel => 'Category';

  @override
  String get productType => 'Product Type';

  @override
  String get productTypeHint => 'e.g. Top';

  @override
  String get pleaseEnterProductTypeError => 'Please enter product type';

  @override
  String get color => 'Color';

  @override
  String get fitLabel => 'Fit';

  @override
  String get fitSlim => 'Slim';

  @override
  String get fitRegular => 'Regular';

  @override
  String get fitRelaxed => 'Relaxed';

  @override
  String get fitOversized => 'Oversized';

  @override
  String get brandOptionalLabel => 'Brand (optional)';

  @override
  String get brandHint => 'What is the brand of this clothing?';

  @override
  String get priceOptionalLabel => 'Price (optional)';

  @override
  String get priceHint => 'How much is this clothing?';

  @override
  String get purchaseDateLabel => 'Purchase date (optional)';

  @override
  String get notUsedInOutfitsYet => 'Not used in any outfits yet';

  @override
  String get usedInOutfits => 'Used in Outfits';

  @override
  String get selectAColor => 'Select Color';

  @override
  String get chooseColorTitle => 'Choose a color';

  @override
  String get clear => 'Clear';

  @override
  String get close => 'Close';

  @override
  String get brand => 'Brand';

  @override
  String get price => 'Price';

  @override
  String get selectDate => 'Select Date';

  @override
  String get editImage => 'Edit image';

  @override
  String get changesSaved => 'Changes Saved';

  @override
  String get itemDeleted => 'Clothing Deleted';

  @override
  String get outfitSaved => 'Outfit Saved';

  @override
  String get outfitDeleted => 'Outfit Deleted';

  @override
  String get midLayer => 'Mid Layer';

  @override
  String get outerwear => 'Outerwear';

  @override
  String get selectCombinationsInstruction =>
      'Choose the pieces you want to wear.';

  @override
  String get editDayOutfitInstruction =>
      'Choose which suitcase items make up this day\'s outfit.';

  @override
  String get creatingOutfitsEllipsis => 'Creating Outfits…';

  @override
  String get loadingClosetEllipsis => 'Loading Closet…';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get genderOther => 'Other';

  @override
  String get genderPreferNotToSay => 'Prefer not to say';

  @override
  String get accountNameLabel => 'Account Name';

  @override
  String get enterYourNameHint => 'Enter your name';

  @override
  String get genderLabel => 'Gender';

  @override
  String get selectGenderHint => 'Select Gender';

  @override
  String get birthdayLabel => 'Birthday';

  @override
  String get selectBirthdayHint => 'Select Birthday';

  @override
  String get homeLocationLabel => 'Home Location';

  @override
  String get selectYourCityHint => 'Select Your City';

  @override
  String get seasonLabel => 'Season';

  @override
  String get styleLabel => 'Style';

  @override
  String get noOutfitsYet => 'No outfits yet.';

  @override
  String get itemNotUsedInOutfitsYet =>
      'This item has not been used in any outfits yet.';

  @override
  String get failedToUpdateFavorite => 'Failed to update favorite';

  @override
  String get creatingTripEllipsis => 'Creating Trip…';

  @override
  String get deletingTripEllipsis => 'Deleting Trip…';

  @override
  String get failedToCreateTrip => 'Failed to create trip';

  @override
  String get tripPlannerTitle => 'Trip Planner';

  @override
  String get loadingTripEllipsis => 'Loading Trip…';

  @override
  String get loadingTripsEllipsis => 'Loading Trips…';

  @override
  String get loadingOutfitsEllipsis => 'Loading Outfits…';

  @override
  String get noTripsPlannedYet => 'No trips planned yet';

  @override
  String get statusOngoing => 'Ongoing';

  @override
  String get statusUpcoming => 'Upcoming';

  @override
  String get statusPast => 'Past';

  @override
  String get upcomingTrip => 'Upcoming Trip';

  @override
  String get failedToUpdateTrip => 'Failed to update trip';

  @override
  String get failedToDeleteTrip => 'Failed to delete trip';

  @override
  String get failedToLoadTripDetails => 'Failed to load trip details';

  @override
  String get creatingEllipsis => 'Creating…';

  @override
  String get generatingEllipsis => 'Generating…';

  @override
  String get dailyOutfitPlan => 'Daily Outfit Plan';

  @override
  String outfitForDate(String date) {
    return 'Outfit for $date';
  }

  @override
  String get noItemsPlanned => 'No items planned';

  @override
  String get thinkingEllipsis => 'Thinking…';

  @override
  String get outfitAdviceLabel => 'Outfit advice';

  @override
  String get suitcaseLabel => 'Suitcase';

  @override
  String get packClothingHint => 'Pack clothing for this trip';

  @override
  String get selectGarmentsTitle => 'Select Garments';

  @override
  String get addFromOutfit => 'Add from an Outfit';

  @override
  String get selectAnOutfitTitle => 'Select an Outfit';

  @override
  String addedItemsFromOutfitCount(int count) {
    return 'Added $count items from this outfit.';
  }

  @override
  String get noNewItemsFromOutfit => 'No new items to add from this outfit.';

  @override
  String noGarmentsInCategory(String category) {
    return 'No garments in $category';
  }

  @override
  String get suggestedByAi => 'Suggested by AI';

  @override
  String get loadingPackingSuggestions => 'Loading packing suggestions…';

  @override
  String recommendedSelectedCount(int recommended, int selected) {
    return 'Recommended $recommended · Selected $selected';
  }

  @override
  String packedItemsCount(int count) {
    return 'Packed $count';
  }

  @override
  String get failedToUpdateSuitcase => 'Failed to update suitcase';

  @override
  String get failedToRemoveItem => 'Failed to remove item';

  @override
  String get loadingSuitcaseEllipsis => 'Loading Suitcase…';

  @override
  String get addGarment => 'Add Garment';

  @override
  String get noGarmentsPackedYet => 'No garments packed yet';

  @override
  String get occasionWork => 'Work';

  @override
  String get occasionCasual => 'Casual';

  @override
  String get occasionWorkout => 'Workout';

  @override
  String get occasionDate => 'Date';

  @override
  String get occasionTravel => 'Travel';

  @override
  String get occasionParty => 'Party';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get comfortAdjustment => 'Comfort Adjustment';

  @override
  String get weeklySchedule => 'Weekly Schedule';

  @override
  String get perceivedTempOffset => 'Perceived temperature offset';

  @override
  String get lifestyleDescription =>
      'Tell Uwearis about your routine and comfort preferences to make daily outfit recommendations more personal.';

  @override
  String get weeklyScheduleIntro =>
      'Set what a typical week looks like for you.';

  @override
  String get comfortAdjustmentIntro =>
      'Fine-tune how warm or cool you usually feel.';

  @override
  String selectOccasionTitle(String day) {
    return 'Select $day\'s Occasion';
  }

  @override
  String get todaysOutfit => 'Today\'s Outfit';

  @override
  String get loadingWeatherEllipsis => 'Loading weather…';

  @override
  String get viewDetails => 'View Details';

  @override
  String get googleLoginNotConfiguredIOS =>
      'Google login is not configured for iOS yet.';

  @override
  String get googleLoginSuccess => 'Google login success';

  @override
  String get appleLoginSuccess => 'Apple login success';

  @override
  String get facebookLoginSuccess => 'Facebook login success';

  @override
  String get loginHeading => 'Log-In / Sign-in to get dressed!';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get signInWithFacebook => 'Sign in with Facebook';

  @override
  String get copyrightText => 'copyright reserved to Uwearis inc.';

  @override
  String get noItemsFound => 'No items found.';

  @override
  String get edit => 'Edit';

  @override
  String get editTagsTitle => 'Edit Tags';

  @override
  String get analyzingClothingEllipsis => 'Analyzing Clothing…';

  @override
  String get analyzingEllipsis => 'Analyzing…';

  @override
  String get confirmed => 'Confirmed';

  @override
  String get reset => 'Reset';

  @override
  String get pinchToZoomHint =>
      'Pinch to zoom the image to make sure the picture have the whole details.';

  @override
  String get retake => 'Retake';

  @override
  String get album => 'Album';

  @override
  String get heightHint => 'Height';

  @override
  String get weightHint => 'Weight';

  @override
  String get feetLabel => 'Feet';

  @override
  String get inchesLabel => 'Inches';

  @override
  String get unitMetricLabel => 'Metric';

  @override
  String get unitImperialLabel => 'Imperial';

  @override
  String get searchLocationTitle => 'Search Location';

  @override
  String get cityNameHint => 'City name...';

  @override
  String get crashScreenTitle => 'Something went wrong';

  @override
  String get crashScreenMessage =>
      'Please restart the app. If the problem continues, contact support.';

  @override
  String get sessionExpiredTitle => 'Session Expired';

  @override
  String get sessionExpiredMessage =>
      'Your session has expired. Please log in again to continue.';

  @override
  String get ok => 'OK';

  @override
  String get googleLoginMissingToken => 'Google login failed: missing ID token';

  @override
  String get appleLoginMissingToken => 'Apple login failed: missing ID token';

  @override
  String get unknownLocation => 'Unknown Location';
}
