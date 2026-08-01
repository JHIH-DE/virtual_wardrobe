// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'LUMI';

  @override
  String get settings => 'Settings';

  @override
  String get account => 'Account';

  @override
  String get aiModel => 'AI Model';

  @override
  String get aiModelDescription =>
      'These references help LUMI understand your appearance for AI outfit try-on and future generated looks.';

  @override
  String get faceReferenceLabel => 'Face Reference';

  @override
  String get faceReferenceDescription =>
      'Used for your face, hairstyle, and facial features — not your body proportions.';

  @override
  String get faceReferenceUploadHint =>
      'Upload a clear, front-facing portrait.';

  @override
  String get faceReferenceComingSoon => 'Coming soon';

  @override
  String get bodyReferenceLabel => 'Body Reference';

  @override
  String get bodyReferenceDescription =>
      'Used for your body shape, height, and overall proportions.';

  @override
  String get aiModelReady => 'Ready · Face + Body Configured';

  @override
  String aiModelReferencesAdded(int count) {
    return '$count/2 References Added';
  }

  @override
  String get styleProfile => 'Style Profile';

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
  String get findYourStyle => 'Find Your Style';

  @override
  String get styleSelectionInstruction =>
      'Choose your styles for personalized outfit picks.';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get remove => 'Remove';

  @override
  String get discard => 'Discard';

  @override
  String get rename => 'Rename';

  @override
  String get share => 'Share';

  @override
  String get delete => 'Delete';

  @override
  String get details => 'Details';

  @override
  String get renameLook => 'Rename Look';

  @override
  String get lookNameLabel => 'Name of this look';

  @override
  String get remixLook => 'Remix Look';

  @override
  String get saveLook => 'Save Look';

  @override
  String get loadingGarments => 'Loading Garments…';

  @override
  String get myCollection => 'My Collection';

  @override
  String get myLook => 'My Look';

  @override
  String get shareComingSoon => 'Share coming soon';

  @override
  String get failedToLoadImage => 'Failed to load image';

  @override
  String get failedToLoadGarments => 'Failed to load garments';

  @override
  String get saveThisLookTitle => 'Save this look?';

  @override
  String get saveThisLookBody =>
      'Would you like to save this look to your collection?';

  @override
  String get deleteLookTitle => 'Delete Look';

  @override
  String get deleteLookConfirmation =>
      'Are you sure you want to delete this look?';

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
  String get setGenderFirstMessage =>
      'Set your gender in Personal Details first — style tags are picked based on it.';

  @override
  String get openPersonalDetails => 'Open Personal Details';

  @override
  String get styleMinimalist => 'Minimalist';

  @override
  String get styleKorean => 'Korean';

  @override
  String get styleStreetwear => 'Streetwear';

  @override
  String get styleSmartCasual => 'Smart Casual';

  @override
  String get styleChic => 'Chic';

  @override
  String get styleAthleisure => 'Athleisure';

  @override
  String get styleOldMoney => 'Old Money';

  @override
  String get styleRomantic => 'Romantic';

  @override
  String get styleVintage => 'Vintage';

  @override
  String get styleBohemian => 'Bohemian';

  @override
  String get styleCityBoy => 'City Boy';

  @override
  String get styleAmericanCasual => 'American Casual';

  @override
  String get styleWorkwear => 'Workwear';

  @override
  String get styleGorpcore => 'Gorpcore';

  @override
  String get styleTechwear => 'Techwear';

  @override
  String get styleOutdoor => 'Outdoor';

  @override
  String get navHome => 'Home';

  @override
  String get navCloset => 'Closet';

  @override
  String get navLooks => 'Looks';

  @override
  String get navTrips => 'Trips';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get quickActionAddClothing => 'Add Clothing';

  @override
  String get quickActionAddLook => 'Add Look';

  @override
  String get newTrip => 'New Trip';

  @override
  String get retry => 'Retry';

  @override
  String get aiTag => 'AI';

  @override
  String get editPhoto => 'Edit Photo';

  @override
  String get uploadImage => 'Upload Image';

  @override
  String get chooseClearPhotoHint => 'Please choose a clear photo.';

  @override
  String get choosePhoto => 'Choose photo';

  @override
  String noOptionsAvailable(String label) {
    return 'No $label available';
  }

  @override
  String get editTripName => 'Edit Trip Name';

  @override
  String get editDestinations => 'Edit Destinations';

  @override
  String get enterTripName => 'Enter trip name';

  @override
  String get editTripPurpose => 'Edit Trip Purpose';

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
  String get tripPurposeLabel => 'Trip Purpose';

  @override
  String get create => 'Create';

  @override
  String get fillAllFieldsError => 'Please fill all fields';

  @override
  String get regenerate => 'Regenerate';

  @override
  String get letLumiPlanOutfits => 'Let LUMI Plan Your Trip';

  @override
  String get letLumiPlanOutfitsHint =>
      'LUMI will build an outfit for every day using what\'s in your suitcase.';

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
  String get insufficientSuitcaseTitle => 'Not Enough in Your Suitcase';

  @override
  String get insufficientSuitcaseBody =>
      'LUMI needs at least one top (or one-piece) and one bottom to plan outfits. Add a few more pieces to your suitcase first.';

  @override
  String get goToSuitcase => 'Go to Suitcase';

  @override
  String get outfitMissingItemsWarning =>
      'Some items in this outfit were removed from your suitcase.';

  @override
  String get fixOutfit => 'Fix';

  @override
  String get loading => 'Loading…';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get generatingLookEllipsis => 'Generating your look…';

  @override
  String get noLookImageYet => 'No look image yet';

  @override
  String get generateLook => 'Generate Look';

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
  String lookFallbackTitle(int id) {
    return 'Look #$id';
  }

  @override
  String get failedToLoad => 'Failed to Load';

  @override
  String get noImage => 'No Image';

  @override
  String get tripPurposeLeisureTravel => 'Leisure Travel';

  @override
  String get tripPurposeBusinessTrip => 'Business Trip';

  @override
  String get tripPurposeFamilyTrip => 'Family Trip';

  @override
  String get tripPurposeOutdoorTrip => 'Outdoor Trip';

  @override
  String get tripPurposeCityTrip => 'City Trip';

  @override
  String get tripPurposeResortVacation => 'Resort / Vacation';

  @override
  String get tripPurposeMixed => 'Mixed';

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
  String get purchaseDateLabel => 'Purchase date';

  @override
  String get notUsedInLooksYet => 'Not used in any looks yet';

  @override
  String get usedInLooks => 'Used in Looks';

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
  String get lookSaved => 'Look Saved';

  @override
  String get lookDeleted => 'Look Deleted';

  @override
  String get midLayer => 'Mid Layer';

  @override
  String get outerwear => 'Outerwear';

  @override
  String get createLook => 'Create Look';

  @override
  String get selectCombinationsInstruction =>
      'Select the clothing combinations you\'d like to try, then click \"Create Look\" to see your try-on results!';

  @override
  String get editDayOutfitInstruction =>
      'Choose which suitcase items make up this day\'s outfit.';

  @override
  String get creatingLooksEllipsis => 'Creating Looks…';

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
  String get noLooksYet => 'No looks yet.';

  @override
  String get itemNotUsedInLooksYet =>
      'This item has not been used in any looks yet.';

  @override
  String get failedToUpdateFavorite => 'Failed to update favorite';

  @override
  String get creatingTripEllipsis => 'Creating Trip…';

  @override
  String get failedToCreateTrip => 'Failed to create trip';

  @override
  String get tripPlannerTitle => 'Trip Planner';

  @override
  String get loadingTripEllipsis => 'Loading Trip…';

  @override
  String get loadingTripsEllipsis => 'Loading Trips…';

  @override
  String get loadingLooksEllipsis => 'Loading Looks…';

  @override
  String get noTripsPlannedYet => 'No trips planned yet';

  @override
  String get statusOngoing => 'Ongoing';

  @override
  String get statusUpcoming => 'Upcoming';

  @override
  String get statusPast => 'Past';

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
  String wardrobeForDate(String date) {
    return 'Wardrobe for $date';
  }

  @override
  String get noItemsPlanned => 'No items planned';

  @override
  String get thinkingEllipsis => 'Thinking…';

  @override
  String get tapToViewAiSummary => 'Tap to view AI Summary';

  @override
  String get suitcaseLabel => 'Suitcase';

  @override
  String get packClothingHint => 'Pack clothing for this trip';

  @override
  String get selectGarmentsTitle => 'Select Garments';

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
  String suitcaseTitleWithName(String name) {
    return '$name Suitcase';
  }

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
  String get lifestyleIntroLine1 =>
      'Tell LUMI what your typical week looks like.';

  @override
  String get lifestyleIntroLine2 =>
      'We\'ll recommend outfits that match your routine.';

  @override
  String get comfortAdjustmentIntro =>
      'Everyone feels temperature differently — fine-tune this to match how you personally feel hot or cold.';

  @override
  String get selectOccasionTitle => 'Select Occasion';

  @override
  String get todaysLook => 'Today\'s Look';

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
  String get copyrightText => 'copyright reserved to LUMI inc.';

  @override
  String get noItemsFound => 'No items found.';

  @override
  String get edit => 'Edit';

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
  String get chooseClearFullBodyPhotoHint =>
      'Please choose a clear, full-body photo.';

  @override
  String get heightHint => 'height';

  @override
  String get weightHint => 'weight';

  @override
  String get searchLocationTitle => 'Search Location';

  @override
  String get cityNameHint => 'City name...';
}
