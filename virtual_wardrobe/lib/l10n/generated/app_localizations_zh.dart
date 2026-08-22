// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'LUMI';

  @override
  String get settings => '設定';

  @override
  String get account => '帳號';

  @override
  String get aiModel => 'AI 模型';

  @override
  String get aiModelDescription =>
      '這些參考資料能幫助 LUMI 了解你的外貌，用於 AI 試穿與未來的 AI 生成穿搭。';

  @override
  String get faceReferenceLabel => '臉部參考';

  @override
  String get faceReferenceDescription => '用於你的臉部、髮型與五官特徵——不會用於身形比例。';

  @override
  String get faceReferenceUploadHint => '請上傳一張清晰的正面大頭照。';

  @override
  String get faceReferenceComingSoon => '即將推出';

  @override
  String get bodyReferenceLabel => '身形參考';

  @override
  String get bodyReferenceDescription => '用於你的身形、身高與整體比例。';

  @override
  String get aiModelReady => '已就緒．臉部與身形皆已設定';

  @override
  String aiModelReferencesAdded(int count) {
    return '已新增 $count/2 項參考資料';
  }

  @override
  String get styleProfile => '風格檔案';

  @override
  String get styleTaste => '風格品味';

  @override
  String get styleTasteSummary => 'LUMI 學習你偏好的穿搭組合方式';

  @override
  String get styleTasteHeroSubtitle => '根據你收藏的穿搭與回饋，LUMI 正在學習你的風格品味。';

  @override
  String get styleTasteDimensionsInfoTitle => '這些代表什麼';

  @override
  String get styleTasteRadarCardTitle => '你的風格品味';

  @override
  String get styleTasteRadarCardSubtitle => '你的風格偏好視覺化總覽。';

  @override
  String styleTasteAnalysisStats(int count, int favoriteCount) {
    return '已分析 $count 套穿搭．$favoriteCount 套收藏';
  }

  @override
  String get lifestyle => '生活風格';

  @override
  String get logout => '登出';

  @override
  String get language => '語言';

  @override
  String get selectLanguageTitle => '選擇語言';

  @override
  String get languageSystemDefault => '跟隨系統';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTraditionalChinese => '繁體中文';

  @override
  String get findYourStyle => '探索你的風格';

  @override
  String get styleSelectionInstruction => '選擇你的風格，獲得個人化穿搭推薦。';

  @override
  String get save => '儲存';

  @override
  String get cancel => '取消';

  @override
  String get remove => '移除';

  @override
  String get discard => '捨棄';

  @override
  String get rename => '重新命名';

  @override
  String get share => '分享';

  @override
  String get delete => '刪除';

  @override
  String get details => '詳情';

  @override
  String get renameOutfit => '重新命名穿搭';

  @override
  String get outfitNameLabel => '這套穿搭的名稱';

  @override
  String get saveOutfit => '儲存穿搭';

  @override
  String get createAnotherVersion => '建立另一個版本';

  @override
  String get customizationOptional => '自訂（選填）';

  @override
  String get currentOutfitLabel => '目前穿搭';

  @override
  String get accessoriesLabel => '配件';

  @override
  String get createOutfit => '建立造型';

  @override
  String get createOutfitHint => '使用這些單品建立另一套穿搭造型';

  @override
  String get sceneLabel => '場景';

  @override
  String get sceneSubtitle => '選擇讓這套穿搭躍然眼前的場景。';

  @override
  String get noneLabel => '無';

  @override
  String selectItemTitle(String item) {
    return '選擇$item';
  }

  @override
  String get loadingGarments => '載入服飾中…';

  @override
  String get myCollection => '我的收藏';

  @override
  String get myOutfit => '我的穿搭';

  @override
  String get shareComingSoon => '分享功能即將推出';

  @override
  String get failedToLoadImage => '圖片載入失敗';

  @override
  String get failedToLoadGarments => '服飾載入失敗';

  @override
  String get saveThisOutfitTitle => '儲存這套穿搭？';

  @override
  String get saveThisOutfitBody => '要將這套穿搭加入你的收藏嗎？';

  @override
  String get deleteOutfitTitle => '刪除穿搭';

  @override
  String get deleteOutfitConfirmation => '確定要刪除這個版本嗎？';

  @override
  String get deleteOutfitGroupConfirmation => '這麼做也會一併刪除跟這套穿搭同批產生的其他穿搭，且無法復原。';

  @override
  String get deleteThisVersion => '刪除版本';

  @override
  String createdOnDate(String date) {
    return '建立於 $date';
  }

  @override
  String outfitTitle(String style) {
    return '$style穿搭';
  }

  @override
  String garmentsCount(int count) {
    return '服飾（$count）';
  }

  @override
  String get setGenderFirstMessage => '請先在個人資料中設定性別，風格標籤會依據性別顯示。';

  @override
  String get openPersonalDetails => '前往個人資料';

  @override
  String get styleMinimalist => '極簡風';

  @override
  String get styleKorean => '韓系風';

  @override
  String get styleStreetwear => '街頭風';

  @override
  String get styleSmartCasual => '商務休閒風';

  @override
  String get styleChic => '時髦風';

  @override
  String get styleAthleisure => '運動休閒風';

  @override
  String get styleOldMoney => '老錢風';

  @override
  String get styleRomantic => '浪漫風';

  @override
  String get styleVintage => '復古風';

  @override
  String get styleBohemian => '波希米亞風';

  @override
  String get styleCityBoy => '城市男孩風';

  @override
  String get styleAmericanCasual => '美式休閒風';

  @override
  String get styleWorkwear => '工裝風';

  @override
  String get styleGorpcore => '山系機能風';

  @override
  String get styleTechwear => '科技機能風';

  @override
  String get styleOutdoor => '戶外風';

  @override
  String get styleTasteStyleBalanceTitle => '風格平衡';

  @override
  String get styleTasteStyleBalanceLow => '一致';

  @override
  String get styleTasteStyleBalanceHigh => '混搭';

  @override
  String get styleTasteStyleBalanceExplanation => '你混搭不同風格的偏好。';

  @override
  String get styleTasteColorPairingTitle => '色彩搭配';

  @override
  String get styleTasteColorPairingLow => '同色調';

  @override
  String get styleTasteColorPairingHigh => '對比色';

  @override
  String get styleTasteColorPairingExplanation => '你搭配顏色的偏好。';

  @override
  String get styleTasteFitPreferenceTitle => '版型偏好';

  @override
  String get styleTasteFitPreferenceLow => '修身';

  @override
  String get styleTasteFitPreferenceHigh => '寬鬆';

  @override
  String get styleTasteFitPreferenceExplanation => '你偏好的衣物版型。';

  @override
  String get styleTasteLayeringTitle => '層次穿搭';

  @override
  String get styleTasteLayeringLow => '簡單';

  @override
  String get styleTasteLayeringHigh => '多層次';

  @override
  String get styleTasteLayeringExplanation => '你偏好疊穿造型的程度。';

  @override
  String get styleTasteAccessoriesTitle => '配件';

  @override
  String get styleTasteAccessoriesLow => '極簡';

  @override
  String get styleTasteAccessoriesHigh => '豐富';

  @override
  String get styleTasteAccessoriesExplanation => '你使用配件的偏好。';

  @override
  String get navHome => '首頁';

  @override
  String get navCloset => '衣櫃';

  @override
  String get navOutfits => '穿搭';

  @override
  String get navTrips => '行程';

  @override
  String get quickActions => '快速操作';

  @override
  String get quickActionAddClothing => '新增衣物';

  @override
  String get quickActionAddOutfit => '新增穿搭';

  @override
  String get newTrip => '新增行程';

  @override
  String get retry => '重試';

  @override
  String get aiTag => 'AI';

  @override
  String get editPhoto => '編輯照片';

  @override
  String get uploadImage => '上傳圖片';

  @override
  String get chooseClearPhotoHint => '請選擇一張清晰的照片。';

  @override
  String get choosePhoto => '選擇照片';

  @override
  String noOptionsAvailable(String label) {
    return '沒有可用的$label';
  }

  @override
  String get editTripName => '編輯名稱';

  @override
  String get editDestinations => '編輯目的地';

  @override
  String get enterTripName => '輸入行程名稱';

  @override
  String get editTripActivities => '編輯活動';

  @override
  String get deleteTrip => '刪除行程';

  @override
  String get deleteTripConfirmation => '確定要刪除這個行程嗎？';

  @override
  String get viewPlan => '查看行程';

  @override
  String get tripNameLabel => '行程名稱';

  @override
  String get tripActivitiesLabel => '行程活動（選填）';

  @override
  String get create => '建立';

  @override
  String get fillAllFieldsError => '請填寫所有欄位';

  @override
  String get regenerate => '重新產生';

  @override
  String get letLumiPlanOutfits => '讓 LUMI 規劃你的行程穿搭';

  @override
  String get letLumiPlanOutfitsHint => 'LUMI 會根據你行李箱裡的衣物，為每一天安排一套穿搭。';

  @override
  String get regeneratePlanTitle => '重新規劃穿搭？';

  @override
  String get regeneratePlanBody => '這會取代每一天目前的穿搭，包含你手動調整過的部分。';

  @override
  String get failedToGeneratePlan => '規劃穿搭失敗';

  @override
  String get generatingPlanEllipsis => '規劃穿搭中…';

  @override
  String get failedToUpdateDayOutfit => '更新穿搭失敗';

  @override
  String get insufficientSuitcaseTitle => '行李箱衣物不足';

  @override
  String get insufficientSuitcaseBody =>
      'LUMI 至少需要一件上衣（或連身衣）和一件下身才能規劃穿搭，請先在行李箱裡多加幾件衣物。';

  @override
  String get goToSuitcase => '前往行李箱';

  @override
  String missingFromSuitcaseCount(int count) {
    return '還有 $count 件尚未打包。';
  }

  @override
  String get addToSuitcase => '加入行李箱';

  @override
  String get loading => '載入中…';

  @override
  String get tryAgain => '再試一次';

  @override
  String get generatingOutfitEllipsis => '正在產生你的穿搭…';

  @override
  String get noOutfitImageYet => '尚無穿搭圖片';

  @override
  String get generateOutfit => '產生穿搭';

  @override
  String get selectDates => '選擇日期';

  @override
  String get startDatePlaceholder => '開始日期';

  @override
  String get endDatePlaceholder => '結束日期';

  @override
  String get booked => '已預訂';

  @override
  String get selected => '已選擇';

  @override
  String get confirm => '確認';

  @override
  String get addLocation => '新增地點';

  @override
  String get addClothingPrompt => '你想如何新增衣物？';

  @override
  String get camera => '拍照';

  @override
  String get photoAlbum => '相簿';

  @override
  String get back => '返回';

  @override
  String outfitFallbackTitle(int id) {
    return '穿搭 #$id';
  }

  @override
  String get failedToLoad => '載入失敗';

  @override
  String get noImage => '無圖片';

  @override
  String get tripActivityOutdoor => '戶外';

  @override
  String get tripActivityBusiness => '商務';

  @override
  String get tripActivityFormalOccasion => '正式場合';

  @override
  String get tripActivityWaterActivities => '水上活動';

  @override
  String get categoryTop => '上衣';

  @override
  String get categoryBottom => '下身';

  @override
  String get categoryOuter => '外套';

  @override
  String get categoryOnePiece => '連身衣';

  @override
  String get categorySocks => '襪子';

  @override
  String get categoryShoes => '鞋子';

  @override
  String get categoryAccessory => '配件';

  @override
  String get categoryTopPlural => '上衣';

  @override
  String get categoryBottomPlural => '下身';

  @override
  String get categoryOuterPlural => '外套';

  @override
  String get categoryOnePiecePlural => '連身衣';

  @override
  String get categoryShoesPlural => '鞋';

  @override
  String get colorBlack => '黑色';

  @override
  String get colorWhite => '白色';

  @override
  String get colorGrey => '灰色';

  @override
  String get colorBeige => '米色';

  @override
  String get colorCream => '奶油色';

  @override
  String get colorBrown => '棕色';

  @override
  String get colorNavy => '海軍藍';

  @override
  String get colorBlue => '藍色';

  @override
  String get colorGreen => '綠色';

  @override
  String get colorOlive => '橄欖綠';

  @override
  String get colorKhaki => '卡其色';

  @override
  String get colorRed => '紅色';

  @override
  String get colorBurgundy => '酒紅色';

  @override
  String get colorYellow => '黃色';

  @override
  String get colorOrange => '橘色';

  @override
  String get colorPink => '粉紅色';

  @override
  String get colorPurple => '紫色';

  @override
  String get renameGarment => '重新命名衣物';

  @override
  String get deleteGarment => '刪除衣物';

  @override
  String get deleteGarmentConfirmation => '確定要刪除這件衣物嗎？';

  @override
  String deleteFailedPrefix(String error) {
    return '刪除失敗：$error';
  }

  @override
  String get unsavedChangesTitle => '你有未儲存的變更';

  @override
  String get unsavedChangesBody => '如果離開此頁面，你的變更將會遺失。';

  @override
  String get dontSave => '不要儲存';

  @override
  String get addToCloset => '加入衣櫃';

  @override
  String get clothingAdded => '已加入衣物';

  @override
  String get recentlyAdded => '最近新增';

  @override
  String garmentPairsWellWith(String subCategory, int count) {
    return '這件$subCategory適合搭配你衣櫃裡的 $count 件單品。';
  }

  @override
  String garmentPairsWellWithGeneric(int count) {
    return '適合搭配你衣櫃裡的 $count 件單品。';
  }

  @override
  String get scoreTierExcellent => '完美百搭';

  @override
  String get scoreTierHighlyVersatile => '百搭度高';

  @override
  String get scoreTierGoodMatch => '適合搭配';

  @override
  String get scoreTierLimitedMatch => '搭配有限';

  @override
  String get scoreTierHardToStyle => '較難搭配';

  @override
  String get clothingNameLabel => '名稱';

  @override
  String get nameTheClothingHint => '為這件衣物命名';

  @override
  String get pleaseEnterNameError => '請輸入名稱';

  @override
  String get clothingCategoryLabel => '類別';

  @override
  String get productType => '商品類型';

  @override
  String get productTypeHint => '例如：上衣';

  @override
  String get pleaseEnterProductTypeError => '請輸入商品類型';

  @override
  String get color => '顏色';

  @override
  String get fitLabel => '版型';

  @override
  String get fitSlim => '修身';

  @override
  String get fitRegular => '標準';

  @override
  String get fitRelaxed => '微寬鬆';

  @override
  String get fitOversized => '寬鬆';

  @override
  String get brandOptionalLabel => '品牌（選填）';

  @override
  String get brandHint => '這件衣物的品牌是？';

  @override
  String get priceOptionalLabel => '價格（選填）';

  @override
  String get priceHint => '這件衣物的價格是？';

  @override
  String get purchaseDateLabel => '購買日期';

  @override
  String get notUsedInOutfitsYet => '尚未用於任何穿搭';

  @override
  String get usedInOutfits => '已用於穿搭';

  @override
  String get selectAColor => '選擇顏色';

  @override
  String get chooseColorTitle => '選擇顏色';

  @override
  String get clear => '清除';

  @override
  String get close => '關閉';

  @override
  String get brand => '品牌';

  @override
  String get price => '價格';

  @override
  String get selectDate => '選擇日期';

  @override
  String get editImage => '編輯圖片';

  @override
  String get changesSaved => '變更已儲存';

  @override
  String get itemDeleted => '已刪除衣物';

  @override
  String get outfitSaved => '穿搭已儲存';

  @override
  String get outfitDeleted => '穿搭已刪除';

  @override
  String get midLayer => '中層';

  @override
  String get outerwear => '外套';

  @override
  String get selectCombinationsInstruction => '選擇你想嘗試的衣物組合，然後點選「建立造型」查看試穿結果！';

  @override
  String get editDayOutfitInstruction => '選擇這天穿搭要用行李箱裡的哪些衣物。';

  @override
  String get creatingOutfitsEllipsis => '建立穿搭中…';

  @override
  String get loadingClosetEllipsis => '載入衣櫃中…';

  @override
  String get genderMale => '男性';

  @override
  String get genderFemale => '女性';

  @override
  String get genderOther => '其他';

  @override
  String get genderPreferNotToSay => '不願透露';

  @override
  String get accountNameLabel => '帳號名稱';

  @override
  String get enterYourNameHint => '輸入你的名字';

  @override
  String get genderLabel => '性別';

  @override
  String get selectGenderHint => '選擇性別';

  @override
  String get birthdayLabel => '生日';

  @override
  String get selectBirthdayHint => '選擇生日';

  @override
  String get homeLocationLabel => '居住地';

  @override
  String get selectYourCityHint => '選擇你的城市';

  @override
  String get seasonLabel => '季節';

  @override
  String get styleLabel => '風格';

  @override
  String get noOutfitsYet => '尚無穿搭。';

  @override
  String get itemNotUsedInOutfitsYet => '這件單品尚未用於任何穿搭。';

  @override
  String get failedToUpdateFavorite => '更新收藏失敗';

  @override
  String get creatingTripEllipsis => '建立行程中…';

  @override
  String get deletingTripEllipsis => '刪除行程中…';

  @override
  String get failedToCreateTrip => '建立行程失敗';

  @override
  String get tripPlannerTitle => '行程規劃';

  @override
  String get loadingTripEllipsis => '載入行程中…';

  @override
  String get loadingTripsEllipsis => '載入行程列表中…';

  @override
  String get loadingOutfitsEllipsis => '載入穿搭中…';

  @override
  String get noTripsPlannedYet => '尚無規劃中的行程';

  @override
  String get statusOngoing => '進行中';

  @override
  String get statusUpcoming => '即將到來';

  @override
  String get statusPast => '已結束';

  @override
  String get upcomingTrip => '即將到來的行程';

  @override
  String get failedToUpdateTrip => '更新行程失敗';

  @override
  String get failedToDeleteTrip => '刪除行程失敗';

  @override
  String get failedToLoadTripDetails => '載入行程詳情失敗';

  @override
  String get creatingEllipsis => '建立中…';

  @override
  String get generatingEllipsis => '產生中…';

  @override
  String get dailyOutfitPlan => '每日穿搭規劃';

  @override
  String outfitForDate(String date) {
    return '$date 的穿搭';
  }

  @override
  String get noItemsPlanned => '尚無規劃項目';

  @override
  String get thinkingEllipsis => '思考中…';

  @override
  String get tapToViewAiSummary => '點擊查看 AI 摘要';

  @override
  String get suitcaseLabel => '行李箱';

  @override
  String get packClothingHint => '為這趟行程打包衣物';

  @override
  String get selectGarmentsTitle => '選擇衣物';

  @override
  String get addFromOutfit => '從穿搭新增';

  @override
  String get selectAnOutfitTitle => '選擇穿搭';

  @override
  String addedItemsFromOutfitCount(int count) {
    return '已從此穿搭新增 $count 件單品。';
  }

  @override
  String get noNewItemsFromOutfit => '這套穿搭沒有可新增的單品。';

  @override
  String noGarmentsInCategory(String category) {
    return '$category中沒有衣物';
  }

  @override
  String get suggestedByAi => 'AI 建議';

  @override
  String get loadingPackingSuggestions => '載入打包建議中…';

  @override
  String recommendedSelectedCount(int recommended, int selected) {
    return '建議 $recommended ‧ 已選 $selected';
  }

  @override
  String packedItemsCount(int count) {
    return '已打包 $count 件';
  }

  @override
  String get failedToUpdateSuitcase => '更新行李箱失敗';

  @override
  String get failedToRemoveItem => '移除項目失敗';

  @override
  String suitcaseTitleWithName(String name) {
    return '$name 的行李箱';
  }

  @override
  String get loadingSuitcaseEllipsis => '載入行李箱中…';

  @override
  String get addGarment => '新增衣物';

  @override
  String get noGarmentsPackedYet => '尚未打包任何衣物';

  @override
  String get occasionWork => '工作';

  @override
  String get occasionCasual => '休閒';

  @override
  String get occasionWorkout => '運動';

  @override
  String get occasionDate => '約會';

  @override
  String get occasionTravel => '旅行';

  @override
  String get occasionParty => '派對';

  @override
  String get settingsSaved => '設定已儲存';

  @override
  String get comfortAdjustment => '舒適度調整';

  @override
  String get weeklySchedule => '每週排程';

  @override
  String get perceivedTempOffset => '體感溫度調整';

  @override
  String get lifestyleIntroLine1 => '告訴 LUMI 你典型的一週作息。';

  @override
  String get lifestyleIntroLine2 => '我們會根據你的日常推薦合適的穿搭。';

  @override
  String get comfortAdjustmentIntro => '每個人對冷熱的感受不同，這裡可以微調成適合你的體感。';

  @override
  String get selectOccasionTitle => '選擇場合';

  @override
  String get todaysOutfit => '今日穿搭';

  @override
  String get loadingWeatherEllipsis => '載入天氣中…';

  @override
  String get viewDetails => '查看詳情';

  @override
  String get googleLoginNotConfiguredIOS => 'iOS 尚未設定 Google 登入。';

  @override
  String get googleLoginSuccess => 'Google 登入成功';

  @override
  String get appleLoginSuccess => 'Apple 登入成功';

  @override
  String get facebookLoginSuccess => 'Facebook 登入成功';

  @override
  String get loginHeading => '登入 / 註冊，開始穿搭吧！';

  @override
  String get continueWithApple => '使用 Apple 繼續';

  @override
  String get signInWithGoogle => '使用 Google 登入';

  @override
  String get signInWithFacebook => '使用 Facebook 登入';

  @override
  String get copyrightText => '版權所有 © LUMI inc.';

  @override
  String get noItemsFound => '找不到項目。';

  @override
  String get edit => '編輯';

  @override
  String get editTagsTitle => '編輯標籤';

  @override
  String get analyzingClothingEllipsis => '分析衣物中…';

  @override
  String get analyzingEllipsis => '分析中…';

  @override
  String get confirmed => '確認';

  @override
  String get reset => '重設';

  @override
  String get pinchToZoomHint => '用兩指縮放圖片，確保照片包含完整細節。';

  @override
  String get retake => '重拍';

  @override
  String get album => '相簿';

  @override
  String get chooseClearFullBodyPhotoHint => '請選擇一張清晰的全身照。';

  @override
  String get heightHint => '身高';

  @override
  String get weightHint => '體重';

  @override
  String get searchLocationTitle => '搜尋地點';

  @override
  String get cityNameHint => '城市名稱...';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appTitle => 'LUMI';

  @override
  String get settings => '設定';

  @override
  String get account => '帳號';

  @override
  String get aiModel => 'AI 模型';

  @override
  String get aiModelDescription =>
      '這些參考資料能幫助 LUMI 了解你的外貌，用於 AI 試穿與未來的 AI 生成穿搭。';

  @override
  String get faceReferenceLabel => '臉部參考';

  @override
  String get faceReferenceDescription => '用於你的臉部、髮型與五官特徵——不會用於身形比例。';

  @override
  String get faceReferenceUploadHint => '請上傳一張清晰的正面大頭照。';

  @override
  String get faceReferenceComingSoon => '即將推出';

  @override
  String get bodyReferenceLabel => '身形參考';

  @override
  String get bodyReferenceDescription => '用於你的身形、身高與整體比例。';

  @override
  String get aiModelReady => '已就緒．臉部與身形皆已設定';

  @override
  String aiModelReferencesAdded(int count) {
    return '已新增 $count/2 項參考資料';
  }

  @override
  String get styleProfile => '風格檔案';

  @override
  String get styleTaste => '風格品味';

  @override
  String get styleTasteSummary => 'LUMI 學習你偏好的穿搭組合方式';

  @override
  String get styleTasteHeroSubtitle => '根據你收藏的穿搭與回饋，LUMI 正在學習你的風格品味。';

  @override
  String get styleTasteDimensionsInfoTitle => '這些代表什麼';

  @override
  String get styleTasteRadarCardTitle => '你的風格品味';

  @override
  String get styleTasteRadarCardSubtitle => '你的風格偏好視覺化總覽。';

  @override
  String styleTasteAnalysisStats(int count, int favoriteCount) {
    return '已分析 $count 套穿搭．$favoriteCount 套收藏';
  }

  @override
  String get lifestyle => '生活風格';

  @override
  String get logout => '登出';

  @override
  String get language => '語言';

  @override
  String get selectLanguageTitle => '選擇語言';

  @override
  String get languageSystemDefault => '跟隨系統';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageTraditionalChinese => '繁體中文';

  @override
  String get findYourStyle => '探索你的風格';

  @override
  String get styleSelectionInstruction => '選擇你的風格，獲得個人化穿搭推薦。';

  @override
  String get save => '儲存';

  @override
  String get cancel => '取消';

  @override
  String get remove => '移除';

  @override
  String get discard => '捨棄';

  @override
  String get rename => '重新命名';

  @override
  String get share => '分享';

  @override
  String get delete => '刪除';

  @override
  String get details => '詳情';

  @override
  String get renameOutfit => '重新命名穿搭';

  @override
  String get outfitNameLabel => '這套穿搭的名稱';

  @override
  String get saveOutfit => '儲存穿搭';

  @override
  String get createAnotherVersion => '建立另一個版本';

  @override
  String get customizationOptional => '自訂（選填）';

  @override
  String get currentOutfitLabel => '目前穿搭';

  @override
  String get accessoriesLabel => '配件';

  @override
  String get createOutfit => '建立造型';

  @override
  String get createOutfitHint => '使用這些單品建立另一套穿搭造型';

  @override
  String get sceneLabel => '場景';

  @override
  String get sceneSubtitle => '選擇讓這套穿搭躍然眼前的場景。';

  @override
  String get noneLabel => '無';

  @override
  String selectItemTitle(String item) {
    return '選擇$item';
  }

  @override
  String get loadingGarments => '載入服飾中…';

  @override
  String get myCollection => '我的收藏';

  @override
  String get myOutfit => '我的穿搭';

  @override
  String get shareComingSoon => '分享功能即將推出';

  @override
  String get failedToLoadImage => '圖片載入失敗';

  @override
  String get failedToLoadGarments => '服飾載入失敗';

  @override
  String get saveThisOutfitTitle => '儲存這套穿搭？';

  @override
  String get saveThisOutfitBody => '要將這套穿搭加入你的收藏嗎？';

  @override
  String get deleteOutfitTitle => '刪除穿搭';

  @override
  String get deleteOutfitConfirmation => '確定要刪除這個版本嗎？';

  @override
  String get deleteOutfitGroupConfirmation => '這麼做也會一併刪除跟這套穿搭同批產生的其他穿搭，且無法復原。';

  @override
  String get deleteThisVersion => '刪除版本';

  @override
  String createdOnDate(String date) {
    return '建立於 $date';
  }

  @override
  String outfitTitle(String style) {
    return '$style穿搭';
  }

  @override
  String garmentsCount(int count) {
    return '服飾（$count）';
  }

  @override
  String get setGenderFirstMessage => '請先在個人資料中設定性別，風格標籤會依據性別顯示。';

  @override
  String get openPersonalDetails => '前往個人資料';

  @override
  String get styleMinimalist => '極簡風';

  @override
  String get styleKorean => '韓系風';

  @override
  String get styleStreetwear => '街頭風';

  @override
  String get styleSmartCasual => '商務休閒風';

  @override
  String get styleChic => '時髦風';

  @override
  String get styleAthleisure => '運動休閒風';

  @override
  String get styleOldMoney => '老錢風';

  @override
  String get styleRomantic => '浪漫風';

  @override
  String get styleVintage => '復古風';

  @override
  String get styleBohemian => '波希米亞風';

  @override
  String get styleCityBoy => '城市男孩風';

  @override
  String get styleAmericanCasual => '美式休閒風';

  @override
  String get styleWorkwear => '工裝風';

  @override
  String get styleGorpcore => '山系機能風';

  @override
  String get styleTechwear => '科技機能風';

  @override
  String get styleOutdoor => '戶外風';

  @override
  String get styleTasteStyleBalanceTitle => '風格平衡';

  @override
  String get styleTasteStyleBalanceLow => '一致';

  @override
  String get styleTasteStyleBalanceHigh => '混搭';

  @override
  String get styleTasteStyleBalanceExplanation => '你混搭不同風格的偏好。';

  @override
  String get styleTasteColorPairingTitle => '色彩搭配';

  @override
  String get styleTasteColorPairingLow => '同色調';

  @override
  String get styleTasteColorPairingHigh => '對比色';

  @override
  String get styleTasteColorPairingExplanation => '你搭配顏色的偏好。';

  @override
  String get styleTasteFitPreferenceTitle => '版型偏好';

  @override
  String get styleTasteFitPreferenceLow => '修身';

  @override
  String get styleTasteFitPreferenceHigh => '寬鬆';

  @override
  String get styleTasteFitPreferenceExplanation => '你偏好的衣物版型。';

  @override
  String get styleTasteLayeringTitle => '層次穿搭';

  @override
  String get styleTasteLayeringLow => '簡單';

  @override
  String get styleTasteLayeringHigh => '多層次';

  @override
  String get styleTasteLayeringExplanation => '你偏好疊穿造型的程度。';

  @override
  String get styleTasteAccessoriesTitle => '配件';

  @override
  String get styleTasteAccessoriesLow => '極簡';

  @override
  String get styleTasteAccessoriesHigh => '豐富';

  @override
  String get styleTasteAccessoriesExplanation => '你使用配件的偏好。';

  @override
  String get navHome => '首頁';

  @override
  String get navCloset => '衣櫃';

  @override
  String get navOutfits => '穿搭';

  @override
  String get navTrips => '行程';

  @override
  String get quickActions => '快速操作';

  @override
  String get quickActionAddClothing => '新增衣物';

  @override
  String get quickActionAddOutfit => '新增穿搭';

  @override
  String get newTrip => '新增行程';

  @override
  String get retry => '重試';

  @override
  String get aiTag => 'AI';

  @override
  String get editPhoto => '編輯照片';

  @override
  String get uploadImage => '上傳圖片';

  @override
  String get chooseClearPhotoHint => '請選擇一張清晰的照片。';

  @override
  String get choosePhoto => '選擇照片';

  @override
  String noOptionsAvailable(String label) {
    return '沒有可用的$label';
  }

  @override
  String get editTripName => '編輯名稱';

  @override
  String get editDestinations => '編輯目的地';

  @override
  String get enterTripName => '輸入行程名稱';

  @override
  String get editTripActivities => '編輯活動';

  @override
  String get deleteTrip => '刪除行程';

  @override
  String get deleteTripConfirmation => '確定要刪除這個行程嗎？';

  @override
  String get viewPlan => '查看行程';

  @override
  String get tripNameLabel => '行程名稱';

  @override
  String get tripActivitiesLabel => '行程活動（選填）';

  @override
  String get create => '建立';

  @override
  String get fillAllFieldsError => '請填寫所有欄位';

  @override
  String get regenerate => '重新產生';

  @override
  String get letLumiPlanOutfits => '讓 LUMI 規劃你的行程穿搭';

  @override
  String get letLumiPlanOutfitsHint => 'LUMI 會根據你行李箱裡的衣物，為每一天安排一套穿搭。';

  @override
  String get regeneratePlanTitle => '重新規劃穿搭？';

  @override
  String get regeneratePlanBody => '這會取代每一天目前的穿搭，包含你手動調整過的部分。';

  @override
  String get failedToGeneratePlan => '規劃穿搭失敗';

  @override
  String get generatingPlanEllipsis => '規劃穿搭中…';

  @override
  String get failedToUpdateDayOutfit => '更新穿搭失敗';

  @override
  String get insufficientSuitcaseTitle => '行李箱衣物不足';

  @override
  String get insufficientSuitcaseBody =>
      'LUMI 至少需要一件上衣（或連身衣）和一件下身才能規劃穿搭，請先在行李箱裡多加幾件衣物。';

  @override
  String get goToSuitcase => '前往行李箱';

  @override
  String missingFromSuitcaseCount(int count) {
    return '還有 $count 件尚未打包。';
  }

  @override
  String get addToSuitcase => '加入行李箱';

  @override
  String get loading => '載入中…';

  @override
  String get tryAgain => '再試一次';

  @override
  String get generatingOutfitEllipsis => '正在產生你的穿搭…';

  @override
  String get noOutfitImageYet => '尚無穿搭圖片';

  @override
  String get generateOutfit => '產生穿搭';

  @override
  String get selectDates => '選擇日期';

  @override
  String get startDatePlaceholder => '開始日期';

  @override
  String get endDatePlaceholder => '結束日期';

  @override
  String get booked => '已預訂';

  @override
  String get selected => '已選擇';

  @override
  String get confirm => '確認';

  @override
  String get addLocation => '新增地點';

  @override
  String get addClothingPrompt => '你想如何新增衣物？';

  @override
  String get camera => '拍照';

  @override
  String get photoAlbum => '相簿';

  @override
  String get back => '返回';

  @override
  String outfitFallbackTitle(int id) {
    return '穿搭 #$id';
  }

  @override
  String get failedToLoad => '載入失敗';

  @override
  String get noImage => '無圖片';

  @override
  String get tripActivityOutdoor => '戶外';

  @override
  String get tripActivityBusiness => '商務';

  @override
  String get tripActivityFormalOccasion => '正式場合';

  @override
  String get tripActivityWaterActivities => '水上活動';

  @override
  String get categoryTop => '上衣';

  @override
  String get categoryBottom => '下身';

  @override
  String get categoryOuter => '外套';

  @override
  String get categoryOnePiece => '連身衣';

  @override
  String get categorySocks => '襪子';

  @override
  String get categoryShoes => '鞋子';

  @override
  String get categoryAccessory => '配件';

  @override
  String get categoryTopPlural => '上衣';

  @override
  String get categoryBottomPlural => '下身';

  @override
  String get categoryOuterPlural => '外套';

  @override
  String get categoryOnePiecePlural => '連身衣';

  @override
  String get categoryShoesPlural => '鞋';

  @override
  String get colorBlack => '黑色';

  @override
  String get colorWhite => '白色';

  @override
  String get colorGrey => '灰色';

  @override
  String get colorBeige => '米色';

  @override
  String get colorCream => '奶油色';

  @override
  String get colorBrown => '棕色';

  @override
  String get colorNavy => '海軍藍';

  @override
  String get colorBlue => '藍色';

  @override
  String get colorGreen => '綠色';

  @override
  String get colorOlive => '橄欖綠';

  @override
  String get colorKhaki => '卡其色';

  @override
  String get colorRed => '紅色';

  @override
  String get colorBurgundy => '酒紅色';

  @override
  String get colorYellow => '黃色';

  @override
  String get colorOrange => '橘色';

  @override
  String get colorPink => '粉紅色';

  @override
  String get colorPurple => '紫色';

  @override
  String get renameGarment => '重新命名衣物';

  @override
  String get deleteGarment => '刪除衣物';

  @override
  String get deleteGarmentConfirmation => '確定要刪除這件衣物嗎？';

  @override
  String deleteFailedPrefix(String error) {
    return '刪除失敗：$error';
  }

  @override
  String get unsavedChangesTitle => '你有未儲存的變更';

  @override
  String get unsavedChangesBody => '如果離開此頁面，你的變更將會遺失。';

  @override
  String get dontSave => '不要儲存';

  @override
  String get addToCloset => '加入衣櫃';

  @override
  String get clothingAdded => '已加入衣物';

  @override
  String get recentlyAdded => '最近新增';

  @override
  String garmentPairsWellWith(String subCategory, int count) {
    return '這件$subCategory適合搭配你衣櫃裡的 $count 件單品。';
  }

  @override
  String garmentPairsWellWithGeneric(int count) {
    return '適合搭配你衣櫃裡的 $count 件單品。';
  }

  @override
  String get scoreTierExcellent => '完美百搭';

  @override
  String get scoreTierHighlyVersatile => '百搭度高';

  @override
  String get scoreTierGoodMatch => '適合搭配';

  @override
  String get scoreTierLimitedMatch => '搭配有限';

  @override
  String get scoreTierHardToStyle => '較難搭配';

  @override
  String get clothingNameLabel => '名稱';

  @override
  String get nameTheClothingHint => '為這件衣物命名';

  @override
  String get pleaseEnterNameError => '請輸入名稱';

  @override
  String get clothingCategoryLabel => '類別';

  @override
  String get productType => '商品類型';

  @override
  String get productTypeHint => '例如：上衣';

  @override
  String get pleaseEnterProductTypeError => '請輸入商品類型';

  @override
  String get color => '顏色';

  @override
  String get fitLabel => '版型';

  @override
  String get fitSlim => '修身';

  @override
  String get fitRegular => '標準';

  @override
  String get fitRelaxed => '微寬鬆';

  @override
  String get fitOversized => '寬鬆';

  @override
  String get brandOptionalLabel => '品牌（選填）';

  @override
  String get brandHint => '這件衣物的品牌是？';

  @override
  String get priceOptionalLabel => '價格（選填）';

  @override
  String get priceHint => '這件衣物的價格是？';

  @override
  String get purchaseDateLabel => '購買日期';

  @override
  String get notUsedInOutfitsYet => '尚未用於任何穿搭';

  @override
  String get usedInOutfits => '已用於穿搭';

  @override
  String get selectAColor => '選擇顏色';

  @override
  String get chooseColorTitle => '選擇顏色';

  @override
  String get clear => '清除';

  @override
  String get close => '關閉';

  @override
  String get brand => '品牌';

  @override
  String get price => '價格';

  @override
  String get selectDate => '選擇日期';

  @override
  String get editImage => '編輯圖片';

  @override
  String get changesSaved => '變更已儲存';

  @override
  String get itemDeleted => '已刪除衣物';

  @override
  String get outfitSaved => '穿搭已儲存';

  @override
  String get outfitDeleted => '穿搭已刪除';

  @override
  String get midLayer => '中層';

  @override
  String get outerwear => '外套';

  @override
  String get selectCombinationsInstruction => '選擇你想嘗試的衣物組合，然後點選「建立造型」查看試穿結果！';

  @override
  String get editDayOutfitInstruction => '選擇這天穿搭要用行李箱裡的哪些衣物。';

  @override
  String get creatingOutfitsEllipsis => '建立穿搭中…';

  @override
  String get loadingClosetEllipsis => '載入衣櫃中…';

  @override
  String get genderMale => '男性';

  @override
  String get genderFemale => '女性';

  @override
  String get genderOther => '其他';

  @override
  String get genderPreferNotToSay => '不願透露';

  @override
  String get accountNameLabel => '帳號名稱';

  @override
  String get enterYourNameHint => '輸入你的名字';

  @override
  String get genderLabel => '性別';

  @override
  String get selectGenderHint => '選擇性別';

  @override
  String get birthdayLabel => '生日';

  @override
  String get selectBirthdayHint => '選擇生日';

  @override
  String get homeLocationLabel => '居住地';

  @override
  String get selectYourCityHint => '選擇你的城市';

  @override
  String get seasonLabel => '季節';

  @override
  String get styleLabel => '風格';

  @override
  String get noOutfitsYet => '尚無穿搭。';

  @override
  String get itemNotUsedInOutfitsYet => '這件單品尚未用於任何穿搭。';

  @override
  String get failedToUpdateFavorite => '更新收藏失敗';

  @override
  String get creatingTripEllipsis => '建立行程中…';

  @override
  String get deletingTripEllipsis => '刪除行程中…';

  @override
  String get failedToCreateTrip => '建立行程失敗';

  @override
  String get tripPlannerTitle => '行程規劃';

  @override
  String get loadingTripEllipsis => '載入行程中…';

  @override
  String get loadingTripsEllipsis => '載入行程列表中…';

  @override
  String get loadingOutfitsEllipsis => '載入穿搭中…';

  @override
  String get noTripsPlannedYet => '尚無規劃中的行程';

  @override
  String get statusOngoing => '進行中';

  @override
  String get statusUpcoming => '即將到來';

  @override
  String get statusPast => '已結束';

  @override
  String get upcomingTrip => '即將到來的行程';

  @override
  String get failedToUpdateTrip => '更新行程失敗';

  @override
  String get failedToDeleteTrip => '刪除行程失敗';

  @override
  String get failedToLoadTripDetails => '載入行程詳情失敗';

  @override
  String get creatingEllipsis => '建立中…';

  @override
  String get generatingEllipsis => '產生中…';

  @override
  String get dailyOutfitPlan => '每日穿搭規劃';

  @override
  String outfitForDate(String date) {
    return '$date 的穿搭';
  }

  @override
  String get noItemsPlanned => '尚無規劃項目';

  @override
  String get thinkingEllipsis => '思考中…';

  @override
  String get tapToViewAiSummary => '點擊查看 AI 摘要';

  @override
  String get suitcaseLabel => '行李箱';

  @override
  String get packClothingHint => '為這趟行程打包衣物';

  @override
  String get selectGarmentsTitle => '選擇衣物';

  @override
  String get addFromOutfit => '從穿搭新增';

  @override
  String get selectAnOutfitTitle => '選擇穿搭';

  @override
  String addedItemsFromOutfitCount(int count) {
    return '已從此穿搭新增 $count 件單品。';
  }

  @override
  String get noNewItemsFromOutfit => '這套穿搭沒有可新增的單品。';

  @override
  String noGarmentsInCategory(String category) {
    return '$category中沒有衣物';
  }

  @override
  String get suggestedByAi => 'AI 建議';

  @override
  String get loadingPackingSuggestions => '載入打包建議中…';

  @override
  String recommendedSelectedCount(int recommended, int selected) {
    return '建議 $recommended ‧ 已選 $selected';
  }

  @override
  String packedItemsCount(int count) {
    return '已打包 $count 件';
  }

  @override
  String get failedToUpdateSuitcase => '更新行李箱失敗';

  @override
  String get failedToRemoveItem => '移除項目失敗';

  @override
  String suitcaseTitleWithName(String name) {
    return '$name 的行李箱';
  }

  @override
  String get loadingSuitcaseEllipsis => '載入行李箱中…';

  @override
  String get addGarment => '新增衣物';

  @override
  String get noGarmentsPackedYet => '尚未打包任何衣物';

  @override
  String get occasionWork => '工作';

  @override
  String get occasionCasual => '休閒';

  @override
  String get occasionWorkout => '運動';

  @override
  String get occasionDate => '約會';

  @override
  String get occasionTravel => '旅行';

  @override
  String get occasionParty => '派對';

  @override
  String get settingsSaved => '設定已儲存';

  @override
  String get comfortAdjustment => '舒適度調整';

  @override
  String get weeklySchedule => '每週排程';

  @override
  String get perceivedTempOffset => '體感溫度調整';

  @override
  String get lifestyleIntroLine1 => '告訴 LUMI 你典型的一週作息。';

  @override
  String get lifestyleIntroLine2 => '我們會根據你的日常推薦合適的穿搭。';

  @override
  String get comfortAdjustmentIntro => '每個人對冷熱的感受不同，這裡可以微調成適合你的體感。';

  @override
  String get selectOccasionTitle => '選擇場合';

  @override
  String get todaysOutfit => '今日穿搭';

  @override
  String get loadingWeatherEllipsis => '載入天氣中…';

  @override
  String get viewDetails => '查看詳情';

  @override
  String get googleLoginNotConfiguredIOS => 'iOS 尚未設定 Google 登入。';

  @override
  String get googleLoginSuccess => 'Google 登入成功';

  @override
  String get appleLoginSuccess => 'Apple 登入成功';

  @override
  String get facebookLoginSuccess => 'Facebook 登入成功';

  @override
  String get loginHeading => '登入 / 註冊，開始穿搭吧！';

  @override
  String get continueWithApple => '使用 Apple 繼續';

  @override
  String get signInWithGoogle => '使用 Google 登入';

  @override
  String get signInWithFacebook => '使用 Facebook 登入';

  @override
  String get copyrightText => '版權所有 © LUMI inc.';

  @override
  String get noItemsFound => '找不到項目。';

  @override
  String get edit => '編輯';

  @override
  String get editTagsTitle => '編輯標籤';

  @override
  String get analyzingClothingEllipsis => '分析衣物中…';

  @override
  String get analyzingEllipsis => '分析中…';

  @override
  String get confirmed => '確認';

  @override
  String get reset => '重設';

  @override
  String get pinchToZoomHint => '用兩指縮放圖片，確保照片包含完整細節。';

  @override
  String get retake => '重拍';

  @override
  String get album => '相簿';

  @override
  String get chooseClearFullBodyPhotoHint => '請選擇一張清晰的全身照。';

  @override
  String get heightHint => '身高';

  @override
  String get weightHint => '體重';

  @override
  String get searchLocationTitle => '搜尋地點';

  @override
  String get cityNameHint => '城市名稱...';
}
