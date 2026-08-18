import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'LUMI'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @aiModel.
  ///
  /// In en, this message translates to:
  /// **'AI Model'**
  String get aiModel;

  /// No description provided for @aiModelDescription.
  ///
  /// In en, this message translates to:
  /// **'These references help LUMI understand your appearance for AI outfit try-on and future generated outfits.'**
  String get aiModelDescription;

  /// No description provided for @faceReferenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Face Reference'**
  String get faceReferenceLabel;

  /// No description provided for @faceReferenceDescription.
  ///
  /// In en, this message translates to:
  /// **'Used for your face, hairstyle, and facial features — not your body proportions.'**
  String get faceReferenceDescription;

  /// No description provided for @faceReferenceUploadHint.
  ///
  /// In en, this message translates to:
  /// **'Upload a clear, front-facing portrait.'**
  String get faceReferenceUploadHint;

  /// No description provided for @faceReferenceComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get faceReferenceComingSoon;

  /// No description provided for @bodyReferenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Body Reference'**
  String get bodyReferenceLabel;

  /// No description provided for @bodyReferenceDescription.
  ///
  /// In en, this message translates to:
  /// **'Used for your body shape, height, and overall proportions.'**
  String get bodyReferenceDescription;

  /// No description provided for @aiModelReady.
  ///
  /// In en, this message translates to:
  /// **'Ready · Face + Body Configured'**
  String get aiModelReady;

  /// No description provided for @aiModelReferencesAdded.
  ///
  /// In en, this message translates to:
  /// **'{count}/2 References Added'**
  String aiModelReferencesAdded(int count);

  /// No description provided for @styleProfile.
  ///
  /// In en, this message translates to:
  /// **'Style Profile'**
  String get styleProfile;

  /// No description provided for @styleTaste.
  ///
  /// In en, this message translates to:
  /// **'Style Taste'**
  String get styleTaste;

  /// No description provided for @styleTasteSummary.
  ///
  /// In en, this message translates to:
  /// **'LUMI learns how you like to put outfits together'**
  String get styleTasteSummary;

  /// No description provided for @styleTasteHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Based on your saved outfits and feedback, LUMI is learning your style taste.'**
  String get styleTasteHeroSubtitle;

  /// No description provided for @styleTasteDimensionsInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'What these mean'**
  String get styleTasteDimensionsInfoTitle;

  /// No description provided for @styleTasteRadarCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Style Taste'**
  String get styleTasteRadarCardTitle;

  /// No description provided for @styleTasteRadarCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A visual summary of your style preferences.'**
  String get styleTasteRadarCardSubtitle;

  /// No description provided for @styleTasteKeyInsightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Key Insights'**
  String get styleTasteKeyInsightsTitle;

  /// Style Taste insight card's stat line — how many saved outfits were analyzed and how many of those are favorites
  ///
  /// In en, this message translates to:
  /// **'Analyzed {count} outfits · {favoriteCount} favorites'**
  String styleTasteAnalysisStats(int count, int favoriteCount);

  /// No description provided for @lifestyle.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle'**
  String get lifestyle;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguageTitle;

  /// No description provided for @languageSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get languageSystemDefault;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageTraditionalChinese.
  ///
  /// In en, this message translates to:
  /// **'繁體中文'**
  String get languageTraditionalChinese;

  /// No description provided for @findYourStyle.
  ///
  /// In en, this message translates to:
  /// **'Find Your Style'**
  String get findYourStyle;

  /// No description provided for @styleSelectionInstruction.
  ///
  /// In en, this message translates to:
  /// **'Choose your styles for personalized outfit picks.'**
  String get styleSelectionInstruction;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @renameOutfit.
  ///
  /// In en, this message translates to:
  /// **'Rename Outfit'**
  String get renameOutfit;

  /// No description provided for @outfitNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name of this outfit'**
  String get outfitNameLabel;

  /// No description provided for @saveOutfit.
  ///
  /// In en, this message translates to:
  /// **'Save Outfit'**
  String get saveOutfit;

  /// No description provided for @createAnotherVersion.
  ///
  /// In en, this message translates to:
  /// **'Create Another Version'**
  String get createAnotherVersion;

  /// No description provided for @customizationLooks.
  ///
  /// In en, this message translates to:
  /// **'Customize (Optional)'**
  String get customizationLooks;

  /// No description provided for @currentOutfitLabel.
  ///
  /// In en, this message translates to:
  /// **'Current Outfit'**
  String get currentOutfitLabel;

  /// No description provided for @accessoriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Accessories'**
  String get accessoriesLabel;

  /// No description provided for @createOutfit.
  ///
  /// In en, this message translates to:
  /// **'Create Outfit'**
  String get createOutfit;

  /// No description provided for @createOutfitHint.
  ///
  /// In en, this message translates to:
  /// **'Create another outfit using these garments'**
  String get createOutfitHint;

  /// No description provided for @sceneLabel.
  ///
  /// In en, this message translates to:
  /// **'Scene'**
  String get sceneLabel;

  /// No description provided for @sceneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose where this look comes to life.'**
  String get sceneSubtitle;

  /// No description provided for @noneLabel.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noneLabel;

  /// No description provided for @selectItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Select {item}'**
  String selectItemTitle(String item);

  /// No description provided for @loadingGarments.
  ///
  /// In en, this message translates to:
  /// **'Loading Garments…'**
  String get loadingGarments;

  /// No description provided for @myCollection.
  ///
  /// In en, this message translates to:
  /// **'My Collection'**
  String get myCollection;

  /// No description provided for @myOutfit.
  ///
  /// In en, this message translates to:
  /// **'My Outfit'**
  String get myOutfit;

  /// No description provided for @shareComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Share coming soon'**
  String get shareComingSoon;

  /// No description provided for @failedToLoadImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image'**
  String get failedToLoadImage;

  /// No description provided for @failedToLoadGarments.
  ///
  /// In en, this message translates to:
  /// **'Failed to load garments'**
  String get failedToLoadGarments;

  /// No description provided for @saveThisOutfitTitle.
  ///
  /// In en, this message translates to:
  /// **'Save this outfit?'**
  String get saveThisOutfitTitle;

  /// No description provided for @saveThisOutfitBody.
  ///
  /// In en, this message translates to:
  /// **'Would you like to save this outfit to your collection?'**
  String get saveThisOutfitBody;

  /// No description provided for @deleteOutfitTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Outfit'**
  String get deleteOutfitTitle;

  /// No description provided for @deleteOutfitConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this outfit?'**
  String get deleteOutfitConfirmation;

  /// No description provided for @deleteLook.
  ///
  /// In en, this message translates to:
  /// **'Delete Look'**
  String get deleteLook;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @lookDeleted.
  ///
  /// In en, this message translates to:
  /// **'Look deleted'**
  String get lookDeleted;

  /// Footer showing the creation date of an outfit
  ///
  /// In en, this message translates to:
  /// **'Created {date}'**
  String createdOnDate(String date);

  /// Auto-generated outfit title built from its first season/style tag
  ///
  /// In en, this message translates to:
  /// **'{style} Outfit'**
  String outfitTitle(String style);

  /// Section header showing how many garments are in an outfit
  ///
  /// In en, this message translates to:
  /// **'Garments ({count})'**
  String garmentsCount(int count);

  /// No description provided for @setGenderFirstMessage.
  ///
  /// In en, this message translates to:
  /// **'Set your gender in Personal Details first — style tags are picked based on it.'**
  String get setGenderFirstMessage;

  /// No description provided for @openPersonalDetails.
  ///
  /// In en, this message translates to:
  /// **'Open Personal Details'**
  String get openPersonalDetails;

  /// No description provided for @styleMinimalist.
  ///
  /// In en, this message translates to:
  /// **'Minimalist'**
  String get styleMinimalist;

  /// No description provided for @styleKorean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get styleKorean;

  /// No description provided for @styleStreetwear.
  ///
  /// In en, this message translates to:
  /// **'Streetwear'**
  String get styleStreetwear;

  /// No description provided for @styleSmartCasual.
  ///
  /// In en, this message translates to:
  /// **'Smart Casual'**
  String get styleSmartCasual;

  /// No description provided for @styleChic.
  ///
  /// In en, this message translates to:
  /// **'Chic'**
  String get styleChic;

  /// No description provided for @styleAthleisure.
  ///
  /// In en, this message translates to:
  /// **'Athleisure'**
  String get styleAthleisure;

  /// No description provided for @styleOldMoney.
  ///
  /// In en, this message translates to:
  /// **'Old Money'**
  String get styleOldMoney;

  /// No description provided for @styleRomantic.
  ///
  /// In en, this message translates to:
  /// **'Romantic'**
  String get styleRomantic;

  /// No description provided for @styleVintage.
  ///
  /// In en, this message translates to:
  /// **'Vintage'**
  String get styleVintage;

  /// No description provided for @styleBohemian.
  ///
  /// In en, this message translates to:
  /// **'Bohemian'**
  String get styleBohemian;

  /// No description provided for @styleCityBoy.
  ///
  /// In en, this message translates to:
  /// **'City Boy'**
  String get styleCityBoy;

  /// No description provided for @styleAmericanCasual.
  ///
  /// In en, this message translates to:
  /// **'American Casual'**
  String get styleAmericanCasual;

  /// No description provided for @styleWorkwear.
  ///
  /// In en, this message translates to:
  /// **'Workwear'**
  String get styleWorkwear;

  /// No description provided for @styleGorpcore.
  ///
  /// In en, this message translates to:
  /// **'Gorpcore'**
  String get styleGorpcore;

  /// No description provided for @styleTechwear.
  ///
  /// In en, this message translates to:
  /// **'Techwear'**
  String get styleTechwear;

  /// No description provided for @styleOutdoor.
  ///
  /// In en, this message translates to:
  /// **'Outdoor'**
  String get styleOutdoor;

  /// No description provided for @styleTasteStyleBalanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Style Balance'**
  String get styleTasteStyleBalanceTitle;

  /// No description provided for @styleTasteStyleBalanceLow.
  ///
  /// In en, this message translates to:
  /// **'Consistent'**
  String get styleTasteStyleBalanceLow;

  /// No description provided for @styleTasteStyleBalanceHigh.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get styleTasteStyleBalanceHigh;

  /// No description provided for @styleTasteColorPairingTitle.
  ///
  /// In en, this message translates to:
  /// **'Color Pairing'**
  String get styleTasteColorPairingTitle;

  /// No description provided for @styleTasteColorPairingLow.
  ///
  /// In en, this message translates to:
  /// **'Tonal'**
  String get styleTasteColorPairingLow;

  /// No description provided for @styleTasteColorPairingHigh.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get styleTasteColorPairingHigh;

  /// No description provided for @styleTasteFitPreferenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Fit Preference'**
  String get styleTasteFitPreferenceTitle;

  /// No description provided for @styleTasteFitPreferenceLow.
  ///
  /// In en, this message translates to:
  /// **'Fitted'**
  String get styleTasteFitPreferenceLow;

  /// No description provided for @styleTasteFitPreferenceHigh.
  ///
  /// In en, this message translates to:
  /// **'Relaxed'**
  String get styleTasteFitPreferenceHigh;

  /// No description provided for @styleTasteLayeringTitle.
  ///
  /// In en, this message translates to:
  /// **'Layering'**
  String get styleTasteLayeringTitle;

  /// No description provided for @styleTasteLayeringLow.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get styleTasteLayeringLow;

  /// No description provided for @styleTasteLayeringHigh.
  ///
  /// In en, this message translates to:
  /// **'Layered'**
  String get styleTasteLayeringHigh;

  /// No description provided for @styleTasteAccessoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Accessories'**
  String get styleTasteAccessoriesTitle;

  /// No description provided for @styleTasteAccessoriesLow.
  ///
  /// In en, this message translates to:
  /// **'Minimal'**
  String get styleTasteAccessoriesLow;

  /// No description provided for @styleTasteAccessoriesHigh.
  ///
  /// In en, this message translates to:
  /// **'Expressive'**
  String get styleTasteAccessoriesHigh;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navCloset.
  ///
  /// In en, this message translates to:
  /// **'Closet'**
  String get navCloset;

  /// No description provided for @navOutfits.
  ///
  /// In en, this message translates to:
  /// **'Outfits'**
  String get navOutfits;

  /// No description provided for @navTrips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get navTrips;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @quickActionAddClothing.
  ///
  /// In en, this message translates to:
  /// **'New Clothing'**
  String get quickActionAddClothing;

  /// No description provided for @quickActionAddOutfit.
  ///
  /// In en, this message translates to:
  /// **'New Outfit'**
  String get quickActionAddOutfit;

  /// No description provided for @newTrip.
  ///
  /// In en, this message translates to:
  /// **'New Trip'**
  String get newTrip;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @aiTag.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get aiTag;

  /// No description provided for @editPhoto.
  ///
  /// In en, this message translates to:
  /// **'Edit Photo'**
  String get editPhoto;

  /// No description provided for @uploadImage.
  ///
  /// In en, this message translates to:
  /// **'Upload Image'**
  String get uploadImage;

  /// No description provided for @chooseClearPhotoHint.
  ///
  /// In en, this message translates to:
  /// **'Please choose a clear photo.'**
  String get chooseClearPhotoHint;

  /// No description provided for @choosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get choosePhoto;

  /// Empty state for a filter group with no selectable options
  ///
  /// In en, this message translates to:
  /// **'No {label} available'**
  String noOptionsAvailable(String label);

  /// No description provided for @editTripName.
  ///
  /// In en, this message translates to:
  /// **'Edit Name'**
  String get editTripName;

  /// No description provided for @editDestinations.
  ///
  /// In en, this message translates to:
  /// **'Edit Destinations'**
  String get editDestinations;

  /// No description provided for @enterTripName.
  ///
  /// In en, this message translates to:
  /// **'Enter trip name'**
  String get enterTripName;

  /// No description provided for @editTripActivities.
  ///
  /// In en, this message translates to:
  /// **'Edit Activities'**
  String get editTripActivities;

  /// No description provided for @deleteTrip.
  ///
  /// In en, this message translates to:
  /// **'Delete Trip'**
  String get deleteTrip;

  /// No description provided for @deleteTripConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this trip?'**
  String get deleteTripConfirmation;

  /// No description provided for @viewPlan.
  ///
  /// In en, this message translates to:
  /// **'View Plan'**
  String get viewPlan;

  /// No description provided for @tripNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Trip Name'**
  String get tripNameLabel;

  /// No description provided for @tripActivitiesLabel.
  ///
  /// In en, this message translates to:
  /// **'Trip Activities (Optional)'**
  String get tripActivitiesLabel;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @fillAllFieldsError.
  ///
  /// In en, this message translates to:
  /// **'Please fill all fields'**
  String get fillAllFieldsError;

  /// No description provided for @regenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get regenerate;

  /// No description provided for @letLumiPlanOutfits.
  ///
  /// In en, this message translates to:
  /// **'Let LUMI Plan Your Trip'**
  String get letLumiPlanOutfits;

  /// No description provided for @letLumiPlanOutfitsHint.
  ///
  /// In en, this message translates to:
  /// **'LUMI will build an outfit for every day using what\'s in your suitcase.'**
  String get letLumiPlanOutfitsHint;

  /// No description provided for @regeneratePlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Regenerate outfit plan?'**
  String get regeneratePlanTitle;

  /// No description provided for @regeneratePlanBody.
  ///
  /// In en, this message translates to:
  /// **'This will replace every day\'s current outfit, including any you\'ve adjusted by hand.'**
  String get regeneratePlanBody;

  /// No description provided for @failedToGeneratePlan.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate outfit plan'**
  String get failedToGeneratePlan;

  /// No description provided for @generatingPlanEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Planning your outfits…'**
  String get generatingPlanEllipsis;

  /// No description provided for @failedToUpdateDayOutfit.
  ///
  /// In en, this message translates to:
  /// **'Failed to update outfit'**
  String get failedToUpdateDayOutfit;

  /// No description provided for @insufficientSuitcaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Not Enough in Your Suitcase'**
  String get insufficientSuitcaseTitle;

  /// No description provided for @insufficientSuitcaseBody.
  ///
  /// In en, this message translates to:
  /// **'LUMI needs at least one top (or one-piece) and one bottom to plan outfits. Add a few more pieces to your suitcase first.'**
  String get insufficientSuitcaseBody;

  /// No description provided for @goToSuitcase.
  ///
  /// In en, this message translates to:
  /// **'Go to Suitcase'**
  String get goToSuitcase;

  /// No description provided for @missingFromSuitcaseCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items aren\'t packed yet.'**
  String missingFromSuitcaseCount(int count);

  /// No description provided for @addToSuitcase.
  ///
  /// In en, this message translates to:
  /// **'Add to Suitcase'**
  String get addToSuitcase;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @generatingOutfitEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Generating your outfit…'**
  String get generatingOutfitEllipsis;

  /// No description provided for @noOutfitImageYet.
  ///
  /// In en, this message translates to:
  /// **'No outfit image yet'**
  String get noOutfitImageYet;

  /// No description provided for @generateOutfit.
  ///
  /// In en, this message translates to:
  /// **'Generate Outfit'**
  String get generateOutfit;

  /// No description provided for @selectDates.
  ///
  /// In en, this message translates to:
  /// **'Select Dates'**
  String get selectDates;

  /// No description provided for @startDatePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get startDatePlaceholder;

  /// No description provided for @endDatePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get endDatePlaceholder;

  /// No description provided for @booked.
  ///
  /// In en, this message translates to:
  /// **'Booked'**
  String get booked;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selected;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @addLocation.
  ///
  /// In en, this message translates to:
  /// **'Add Location'**
  String get addLocation;

  /// No description provided for @addClothingPrompt.
  ///
  /// In en, this message translates to:
  /// **'How would you like to add a new clothing?'**
  String get addClothingPrompt;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @photoAlbum.
  ///
  /// In en, this message translates to:
  /// **'Photo Album'**
  String get photoAlbum;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Fallback outfit card title when the outfit has no name or tags
  ///
  /// In en, this message translates to:
  /// **'Outfit #{id}'**
  String outfitFallbackTitle(int id);

  /// No description provided for @failedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to Load'**
  String get failedToLoad;

  /// No description provided for @noImage.
  ///
  /// In en, this message translates to:
  /// **'No Image'**
  String get noImage;

  /// No description provided for @tripActivityOutdoor.
  ///
  /// In en, this message translates to:
  /// **'Outdoor'**
  String get tripActivityOutdoor;

  /// No description provided for @tripActivityBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get tripActivityBusiness;

  /// No description provided for @tripActivityFormalOccasion.
  ///
  /// In en, this message translates to:
  /// **'Formal Occasion'**
  String get tripActivityFormalOccasion;

  /// No description provided for @tripActivityWaterActivities.
  ///
  /// In en, this message translates to:
  /// **'Water Activities'**
  String get tripActivityWaterActivities;

  /// No description provided for @categoryTop.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get categoryTop;

  /// No description provided for @categoryBottom.
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get categoryBottom;

  /// No description provided for @categoryOuter.
  ///
  /// In en, this message translates to:
  /// **'Outer'**
  String get categoryOuter;

  /// No description provided for @categoryOnePiece.
  ///
  /// In en, this message translates to:
  /// **'One-piece'**
  String get categoryOnePiece;

  /// No description provided for @categorySocks.
  ///
  /// In en, this message translates to:
  /// **'Socks'**
  String get categorySocks;

  /// No description provided for @categoryShoes.
  ///
  /// In en, this message translates to:
  /// **'Shoes'**
  String get categoryShoes;

  /// No description provided for @categoryAccessory.
  ///
  /// In en, this message translates to:
  /// **'Accessory'**
  String get categoryAccessory;

  /// No description provided for @categoryTopPlural.
  ///
  /// In en, this message translates to:
  /// **'Tops'**
  String get categoryTopPlural;

  /// No description provided for @categoryBottomPlural.
  ///
  /// In en, this message translates to:
  /// **'Bottoms'**
  String get categoryBottomPlural;

  /// No description provided for @categoryOuterPlural.
  ///
  /// In en, this message translates to:
  /// **'Outers'**
  String get categoryOuterPlural;

  /// No description provided for @categoryOnePiecePlural.
  ///
  /// In en, this message translates to:
  /// **'One-pieces'**
  String get categoryOnePiecePlural;

  /// No description provided for @categoryShoesPlural.
  ///
  /// In en, this message translates to:
  /// **'Shoes'**
  String get categoryShoesPlural;

  /// No description provided for @colorBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get colorBlack;

  /// No description provided for @colorWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get colorWhite;

  /// No description provided for @colorGrey.
  ///
  /// In en, this message translates to:
  /// **'Grey'**
  String get colorGrey;

  /// No description provided for @colorBeige.
  ///
  /// In en, this message translates to:
  /// **'Beige'**
  String get colorBeige;

  /// No description provided for @colorCream.
  ///
  /// In en, this message translates to:
  /// **'Cream'**
  String get colorCream;

  /// No description provided for @colorBrown.
  ///
  /// In en, this message translates to:
  /// **'Brown'**
  String get colorBrown;

  /// No description provided for @colorNavy.
  ///
  /// In en, this message translates to:
  /// **'Navy'**
  String get colorNavy;

  /// No description provided for @colorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorBlue;

  /// No description provided for @colorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorGreen;

  /// No description provided for @colorOlive.
  ///
  /// In en, this message translates to:
  /// **'Olive'**
  String get colorOlive;

  /// No description provided for @colorKhaki.
  ///
  /// In en, this message translates to:
  /// **'Khaki'**
  String get colorKhaki;

  /// No description provided for @colorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get colorRed;

  /// No description provided for @colorBurgundy.
  ///
  /// In en, this message translates to:
  /// **'Burgundy'**
  String get colorBurgundy;

  /// No description provided for @colorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get colorYellow;

  /// No description provided for @colorOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get colorOrange;

  /// No description provided for @colorPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get colorPink;

  /// No description provided for @colorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get colorPurple;

  /// No description provided for @renameGarment.
  ///
  /// In en, this message translates to:
  /// **'Rename Garment'**
  String get renameGarment;

  /// No description provided for @deleteGarment.
  ///
  /// In en, this message translates to:
  /// **'Delete Garment'**
  String get deleteGarment;

  /// No description provided for @deleteGarmentConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this garment?'**
  String get deleteGarmentConfirmation;

  /// No description provided for @deleteFailedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String deleteFailedPrefix(String error);

  /// No description provided for @unsavedChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes'**
  String get unsavedChangesTitle;

  /// No description provided for @unsavedChangesBody.
  ///
  /// In en, this message translates to:
  /// **'If you leave this page, your changes will be lost.'**
  String get unsavedChangesBody;

  /// No description provided for @dontSave.
  ///
  /// In en, this message translates to:
  /// **'Don\'t Save'**
  String get dontSave;

  /// No description provided for @addToCloset.
  ///
  /// In en, this message translates to:
  /// **'Add to Closet'**
  String get addToCloset;

  /// No description provided for @clothingAdded.
  ///
  /// In en, this message translates to:
  /// **'Clothing Added'**
  String get clothingAdded;

  /// No description provided for @recentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently Added'**
  String get recentlyAdded;

  /// No description provided for @garmentPairsWellWith.
  ///
  /// In en, this message translates to:
  /// **'This {subCategory} pairs well with {count} items in your closet.'**
  String garmentPairsWellWith(String subCategory, int count);

  /// No description provided for @garmentPairsWellWithGeneric.
  ///
  /// In en, this message translates to:
  /// **'Pairs well with {count} items in your closet.'**
  String garmentPairsWellWithGeneric(int count);

  /// No description provided for @scoreTierExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent Match'**
  String get scoreTierExcellent;

  /// No description provided for @scoreTierHighlyVersatile.
  ///
  /// In en, this message translates to:
  /// **'Highly Versatile'**
  String get scoreTierHighlyVersatile;

  /// No description provided for @scoreTierGoodMatch.
  ///
  /// In en, this message translates to:
  /// **'Good Match'**
  String get scoreTierGoodMatch;

  /// No description provided for @scoreTierLimitedMatch.
  ///
  /// In en, this message translates to:
  /// **'Limited Match'**
  String get scoreTierLimitedMatch;

  /// No description provided for @scoreTierHardToStyle.
  ///
  /// In en, this message translates to:
  /// **'Hard to Style'**
  String get scoreTierHardToStyle;

  /// No description provided for @clothingNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get clothingNameLabel;

  /// No description provided for @nameTheClothingHint.
  ///
  /// In en, this message translates to:
  /// **'Name the clothing'**
  String get nameTheClothingHint;

  /// No description provided for @pleaseEnterNameError.
  ///
  /// In en, this message translates to:
  /// **'Please enter name'**
  String get pleaseEnterNameError;

  /// No description provided for @clothingCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get clothingCategoryLabel;

  /// No description provided for @productType.
  ///
  /// In en, this message translates to:
  /// **'Product Type'**
  String get productType;

  /// No description provided for @productTypeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Top'**
  String get productTypeHint;

  /// No description provided for @pleaseEnterProductTypeError.
  ///
  /// In en, this message translates to:
  /// **'Please enter product type'**
  String get pleaseEnterProductTypeError;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @fitLabel.
  ///
  /// In en, this message translates to:
  /// **'Fit'**
  String get fitLabel;

  /// No description provided for @fitSlim.
  ///
  /// In en, this message translates to:
  /// **'Slim'**
  String get fitSlim;

  /// No description provided for @fitRegular.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get fitRegular;

  /// No description provided for @fitRelaxed.
  ///
  /// In en, this message translates to:
  /// **'Relaxed'**
  String get fitRelaxed;

  /// No description provided for @fitOversized.
  ///
  /// In en, this message translates to:
  /// **'Oversized'**
  String get fitOversized;

  /// No description provided for @brandOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Brand (optional)'**
  String get brandOptionalLabel;

  /// No description provided for @brandHint.
  ///
  /// In en, this message translates to:
  /// **'What is the brand of this clothing?'**
  String get brandHint;

  /// No description provided for @priceOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Price (optional)'**
  String get priceOptionalLabel;

  /// No description provided for @priceHint.
  ///
  /// In en, this message translates to:
  /// **'How much is this clothing?'**
  String get priceHint;

  /// No description provided for @purchaseDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Purchase date'**
  String get purchaseDateLabel;

  /// No description provided for @notUsedInOutfitsYet.
  ///
  /// In en, this message translates to:
  /// **'Not used in any outfits yet'**
  String get notUsedInOutfitsYet;

  /// No description provided for @usedInOutfits.
  ///
  /// In en, this message translates to:
  /// **'Used in Outfits'**
  String get usedInOutfits;

  /// No description provided for @selectAColor.
  ///
  /// In en, this message translates to:
  /// **'Select Color'**
  String get selectAColor;

  /// No description provided for @chooseColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a color'**
  String get chooseColorTitle;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @brand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get brand;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get selectDate;

  /// No description provided for @editImage.
  ///
  /// In en, this message translates to:
  /// **'Edit image'**
  String get editImage;

  /// No description provided for @changesSaved.
  ///
  /// In en, this message translates to:
  /// **'Changes Saved'**
  String get changesSaved;

  /// No description provided for @itemDeleted.
  ///
  /// In en, this message translates to:
  /// **'Clothing Deleted'**
  String get itemDeleted;

  /// No description provided for @outfitSaved.
  ///
  /// In en, this message translates to:
  /// **'Outfit Saved'**
  String get outfitSaved;

  /// No description provided for @outfitDeleted.
  ///
  /// In en, this message translates to:
  /// **'Outfit Deleted'**
  String get outfitDeleted;

  /// No description provided for @midLayer.
  ///
  /// In en, this message translates to:
  /// **'Mid Layer'**
  String get midLayer;

  /// No description provided for @outerwear.
  ///
  /// In en, this message translates to:
  /// **'Outerwear'**
  String get outerwear;

  /// No description provided for @selectCombinationsInstruction.
  ///
  /// In en, this message translates to:
  /// **'Select the clothing combinations you\'d like to try, then click \"Create Outfit\" to see your try-on results!'**
  String get selectCombinationsInstruction;

  /// No description provided for @editDayOutfitInstruction.
  ///
  /// In en, this message translates to:
  /// **'Choose which suitcase items make up this day\'s outfit.'**
  String get editDayOutfitInstruction;

  /// No description provided for @creatingOutfitsEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Creating Outfits…'**
  String get creatingOutfitsEllipsis;

  /// No description provided for @loadingClosetEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Loading Closet…'**
  String get loadingClosetEllipsis;

  /// No description provided for @genderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// No description provided for @genderOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get genderOther;

  /// No description provided for @genderPreferNotToSay.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get genderPreferNotToSay;

  /// No description provided for @accountNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Account Name'**
  String get accountNameLabel;

  /// No description provided for @enterYourNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get enterYourNameHint;

  /// No description provided for @genderLabel.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get genderLabel;

  /// No description provided for @selectGenderHint.
  ///
  /// In en, this message translates to:
  /// **'Select Gender'**
  String get selectGenderHint;

  /// No description provided for @birthdayLabel.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get birthdayLabel;

  /// No description provided for @selectBirthdayHint.
  ///
  /// In en, this message translates to:
  /// **'Select Birthday'**
  String get selectBirthdayHint;

  /// No description provided for @homeLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Home Location'**
  String get homeLocationLabel;

  /// No description provided for @selectYourCityHint.
  ///
  /// In en, this message translates to:
  /// **'Select Your City'**
  String get selectYourCityHint;

  /// No description provided for @seasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get seasonLabel;

  /// No description provided for @styleLabel.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get styleLabel;

  /// No description provided for @noOutfitsYet.
  ///
  /// In en, this message translates to:
  /// **'No outfits yet.'**
  String get noOutfitsYet;

  /// No description provided for @itemNotUsedInOutfitsYet.
  ///
  /// In en, this message translates to:
  /// **'This item has not been used in any outfits yet.'**
  String get itemNotUsedInOutfitsYet;

  /// No description provided for @failedToUpdateFavorite.
  ///
  /// In en, this message translates to:
  /// **'Failed to update favorite'**
  String get failedToUpdateFavorite;

  /// No description provided for @creatingTripEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Creating Trip…'**
  String get creatingTripEllipsis;

  /// No description provided for @failedToCreateTrip.
  ///
  /// In en, this message translates to:
  /// **'Failed to create trip'**
  String get failedToCreateTrip;

  /// No description provided for @tripPlannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip Planner'**
  String get tripPlannerTitle;

  /// No description provided for @loadingTripEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Loading Trip…'**
  String get loadingTripEllipsis;

  /// No description provided for @loadingTripsEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Loading Trips…'**
  String get loadingTripsEllipsis;

  /// No description provided for @loadingOutfitsEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Loading Outfits…'**
  String get loadingOutfitsEllipsis;

  /// No description provided for @noTripsPlannedYet.
  ///
  /// In en, this message translates to:
  /// **'No trips planned yet'**
  String get noTripsPlannedYet;

  /// No description provided for @statusOngoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get statusOngoing;

  /// No description provided for @statusUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get statusUpcoming;

  /// No description provided for @statusPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get statusPast;

  /// No description provided for @upcomingTrip.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Trip'**
  String get upcomingTrip;

  /// No description provided for @failedToUpdateTrip.
  ///
  /// In en, this message translates to:
  /// **'Failed to update trip'**
  String get failedToUpdateTrip;

  /// No description provided for @failedToDeleteTrip.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete trip'**
  String get failedToDeleteTrip;

  /// No description provided for @failedToLoadTripDetails.
  ///
  /// In en, this message translates to:
  /// **'Failed to load trip details'**
  String get failedToLoadTripDetails;

  /// No description provided for @creatingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Creating…'**
  String get creatingEllipsis;

  /// No description provided for @generatingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get generatingEllipsis;

  /// No description provided for @dailyOutfitPlan.
  ///
  /// In en, this message translates to:
  /// **'Daily Outfit Plan'**
  String get dailyOutfitPlan;

  /// No description provided for @outfitForDate.
  ///
  /// In en, this message translates to:
  /// **'Outfit for {date}'**
  String outfitForDate(String date);

  /// No description provided for @noItemsPlanned.
  ///
  /// In en, this message translates to:
  /// **'No items planned'**
  String get noItemsPlanned;

  /// No description provided for @thinkingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get thinkingEllipsis;

  /// No description provided for @tapToViewAiSummary.
  ///
  /// In en, this message translates to:
  /// **'Tap to view AI Summary'**
  String get tapToViewAiSummary;

  /// No description provided for @suitcaseLabel.
  ///
  /// In en, this message translates to:
  /// **'Suitcase'**
  String get suitcaseLabel;

  /// No description provided for @packClothingHint.
  ///
  /// In en, this message translates to:
  /// **'Pack clothing for this trip'**
  String get packClothingHint;

  /// No description provided for @selectGarmentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Garments'**
  String get selectGarmentsTitle;

  /// No description provided for @addFromOutfit.
  ///
  /// In en, this message translates to:
  /// **'Add from an Outfit'**
  String get addFromOutfit;

  /// No description provided for @selectAnOutfitTitle.
  ///
  /// In en, this message translates to:
  /// **'Select an Outfit'**
  String get selectAnOutfitTitle;

  /// No description provided for @addedItemsFromOutfitCount.
  ///
  /// In en, this message translates to:
  /// **'Added {count} items from this outfit.'**
  String addedItemsFromOutfitCount(int count);

  /// No description provided for @noNewItemsFromOutfit.
  ///
  /// In en, this message translates to:
  /// **'No new items to add from this outfit.'**
  String get noNewItemsFromOutfit;

  /// No description provided for @noGarmentsInCategory.
  ///
  /// In en, this message translates to:
  /// **'No garments in {category}'**
  String noGarmentsInCategory(String category);

  /// No description provided for @suggestedByAi.
  ///
  /// In en, this message translates to:
  /// **'Suggested by AI'**
  String get suggestedByAi;

  /// No description provided for @loadingPackingSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Loading packing suggestions…'**
  String get loadingPackingSuggestions;

  /// No description provided for @recommendedSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'Recommended {recommended} · Selected {selected}'**
  String recommendedSelectedCount(int recommended, int selected);

  /// Suitcase card summary before AI packing recommendations have loaded
  ///
  /// In en, this message translates to:
  /// **'Packed {count}'**
  String packedItemsCount(int count);

  /// No description provided for @failedToUpdateSuitcase.
  ///
  /// In en, this message translates to:
  /// **'Failed to update suitcase'**
  String get failedToUpdateSuitcase;

  /// No description provided for @failedToRemoveItem.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove item'**
  String get failedToRemoveItem;

  /// No description provided for @suitcaseTitleWithName.
  ///
  /// In en, this message translates to:
  /// **'{name} Suitcase'**
  String suitcaseTitleWithName(String name);

  /// No description provided for @loadingSuitcaseEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Loading Suitcase…'**
  String get loadingSuitcaseEllipsis;

  /// No description provided for @addGarment.
  ///
  /// In en, this message translates to:
  /// **'Add Garment'**
  String get addGarment;

  /// No description provided for @noGarmentsPackedYet.
  ///
  /// In en, this message translates to:
  /// **'No garments packed yet'**
  String get noGarmentsPackedYet;

  /// No description provided for @occasionWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get occasionWork;

  /// No description provided for @occasionCasual.
  ///
  /// In en, this message translates to:
  /// **'Casual'**
  String get occasionCasual;

  /// No description provided for @occasionWorkout.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get occasionWorkout;

  /// No description provided for @occasionDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get occasionDate;

  /// No description provided for @occasionTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get occasionTravel;

  /// No description provided for @occasionParty.
  ///
  /// In en, this message translates to:
  /// **'Party'**
  String get occasionParty;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get settingsSaved;

  /// No description provided for @comfortAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Comfort Adjustment'**
  String get comfortAdjustment;

  /// No description provided for @weeklySchedule.
  ///
  /// In en, this message translates to:
  /// **'Weekly Schedule'**
  String get weeklySchedule;

  /// No description provided for @perceivedTempOffset.
  ///
  /// In en, this message translates to:
  /// **'Perceived temperature offset'**
  String get perceivedTempOffset;

  /// No description provided for @lifestyleIntroLine1.
  ///
  /// In en, this message translates to:
  /// **'Tell LUMI what your typical week looks like.'**
  String get lifestyleIntroLine1;

  /// No description provided for @lifestyleIntroLine2.
  ///
  /// In en, this message translates to:
  /// **'We\'ll recommend outfits that match your routine.'**
  String get lifestyleIntroLine2;

  /// No description provided for @comfortAdjustmentIntro.
  ///
  /// In en, this message translates to:
  /// **'Everyone feels temperature differently — fine-tune this to match how you personally feel hot or cold.'**
  String get comfortAdjustmentIntro;

  /// No description provided for @selectOccasionTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Occasion'**
  String get selectOccasionTitle;

  /// No description provided for @todaysOutfit.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Outfit'**
  String get todaysOutfit;

  /// No description provided for @loadingWeatherEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Loading weather…'**
  String get loadingWeatherEllipsis;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided for @googleLoginNotConfiguredIOS.
  ///
  /// In en, this message translates to:
  /// **'Google login is not configured for iOS yet.'**
  String get googleLoginNotConfiguredIOS;

  /// No description provided for @googleLoginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Google login success'**
  String get googleLoginSuccess;

  /// No description provided for @appleLoginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Apple login success'**
  String get appleLoginSuccess;

  /// No description provided for @facebookLoginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Facebook login success'**
  String get facebookLoginSuccess;

  /// No description provided for @loginHeading.
  ///
  /// In en, this message translates to:
  /// **'Log-In / Sign-in to get dressed!'**
  String get loginHeading;

  /// No description provided for @continueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continueWithApple;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @signInWithFacebook.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Facebook'**
  String get signInWithFacebook;

  /// No description provided for @copyrightText.
  ///
  /// In en, this message translates to:
  /// **'copyright reserved to LUMI inc.'**
  String get copyrightText;

  /// No description provided for @noItemsFound.
  ///
  /// In en, this message translates to:
  /// **'No items found.'**
  String get noItemsFound;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @editTagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Tags'**
  String get editTagsTitle;

  /// No description provided for @analyzingClothingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Analyzing Clothing…'**
  String get analyzingClothingEllipsis;

  /// No description provided for @analyzingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Analyzing…'**
  String get analyzingEllipsis;

  /// No description provided for @confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmed;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @pinchToZoomHint.
  ///
  /// In en, this message translates to:
  /// **'Pinch to zoom the image to make sure the picture have the whole details.'**
  String get pinchToZoomHint;

  /// No description provided for @retake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get retake;

  /// No description provided for @album.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get album;

  /// No description provided for @chooseClearFullBodyPhotoHint.
  ///
  /// In en, this message translates to:
  /// **'Please choose a clear, full-body photo.'**
  String get chooseClearFullBodyPhotoHint;

  /// No description provided for @heightHint.
  ///
  /// In en, this message translates to:
  /// **'height'**
  String get heightHint;

  /// No description provided for @weightHint.
  ///
  /// In en, this message translates to:
  /// **'weight'**
  String get weightHint;

  /// No description provided for @searchLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Search Location'**
  String get searchLocationTitle;

  /// No description provided for @cityNameHint.
  ///
  /// In en, this message translates to:
  /// **'City name...'**
  String get cityNameHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
