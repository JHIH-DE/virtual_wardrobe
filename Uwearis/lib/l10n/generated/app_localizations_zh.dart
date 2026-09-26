// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Uwearis';

  @override
  String get settings => '設定';

  @override
  String get account => '帳號';

  @override
  String get profilePhotoTitle => '個人頭像';

  @override
  String get aiModel => '試穿檔案';

  @override
  String get aiModelDescription => '新增參考照片，幫助 Uwearis 打造更精準的試穿效果。';

  @override
  String get faceReferenceLabel => '臉部參考';

  @override
  String get faceReferenceComingSoon => '即將推出';

  @override
  String get bodyReferenceLabel => '身形參考';

  @override
  String get bodyMeasurementsLabel => '身形數據';

  @override
  String get faceAppearanceSubtitle => '臉部、髮型與五官特徵';

  @override
  String get bodyProportionsSubtitle => '身形與整體比例';

  @override
  String get changePhotoAction => '更換照片';

  @override
  String get addPhotoAction => '新增照片';

  @override
  String get profileSaveFailed => '无法保存个人资料，请再试一次。';

  @override
  String get photoUploadFailed => '照片上传失败，请再试一次。';

  @override
  String get faceReferenceNotFound => '脸部参考照片已失效，请重新上传。';

  @override
  String get bodyReferenceNotFound => '身形参考照片已失效，请重新上传。';

  @override
  String get fileNotFound => '所需文件已不存在，请重新上传或再试一次。';

  @override
  String get faceReferenceLoadFailedTitle => '脸部参考照片无法加载';

  @override
  String get bodyReferenceLoadFailedTitle => '身形参考照片无法加载';

  @override
  String get referenceLoadFailedSubtitle => '请重新上传照片';

  @override
  String get reuploadPhotoAction => '重新上传';

  @override
  String get aiModelReady => '已就緒．臉部與身形皆已設定';

  @override
  String aiModelReferencesAdded(int count) {
    return '已新增 $count/2 項參考資料';
  }

  @override
  String get styleTaste => '風格品味';

  @override
  String get styleTasteDetailsLabel => '風格洞察';

  @override
  String get styleTasteSummary => 'Uwearis 學習你偏好的穿搭組合方式';

  @override
  String get styleTasteHeroSubtitle => '根據你收藏的穿搭與回饋，Uwearis 正在學習你的風格品味。';

  @override
  String get styleTasteDimensionsInfoTitle => '這些代表什麼';

  @override
  String get styleTasteRadarCardTitle => '你的風格品味';

  @override
  String get styleTasteRadarCardSubtitle => '你的風格偏好視覺化總覽。';

  @override
  String get styleProfileCardTitle => '風格分布';

  @override
  String get styleProfileCardSubtitle => '你的穿搭依風格的分布情況。';

  @override
  String get styleProfileOther => '其他';

  @override
  String styleTasteAnalysisStats(int count, int favoriteCount) {
    return '已分析 $count 套穿搭．$favoriteCount 套收藏';
  }

  @override
  String get lifestyle => '生活風格';

  @override
  String get logout => '登出';

  @override
  String get logoutConfirmTitle => '確定要登出嗎?';

  @override
  String get logoutConfirmBody => '登出後需要重新登入才能使用 Uwearis。';

  @override
  String get deleteAccount => '刪除帳號';

  @override
  String get deleteAccountConfirmTitle => '確定要刪除帳號嗎？';

  @override
  String get deleteAccountConfirmBody =>
      '這將永久刪除您的帳號與所有資料——穿搭、衣物、照片與偏好設定，且無法復原。';

  @override
  String get deletingAccount => '正在刪除帳號…';

  @override
  String get deleteAccountFailed => '刪除帳號失敗，請稍後再試。';

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
  String get save => '儲存';

  @override
  String get cancel => '取消';

  @override
  String get remove => '移除';

  @override
  String get rename => '重新命名';

  @override
  String get share => '分享';

  @override
  String get shareThisPiece => '分享這件單品';

  @override
  String get shareThisOutfit => '分享這套穿搭';

  @override
  String get shareImageUnavailable => '圖片載入失敗。';

  @override
  String get shareFailed => '分享失敗，請再試一次。';

  @override
  String get delete => '刪除';

  @override
  String get details => '詳情';

  @override
  String get renameOutfit => '重新命名穿搭';

  @override
  String get outfitNameLabel => '這套穿搭的名稱';

  @override
  String get addVersionButton => '新版本';

  @override
  String get addVersionTitle => '新增版本';

  @override
  String get versionLimitReachedTitle => '已達版本上限';

  @override
  String get versionLimitReachedBody => '每套穿搭最多可保留 10 個版本，請先刪除一個版本再新增。';

  @override
  String get addToMyOutfits => '加入我的穿搭';

  @override
  String get selectOutfitGroupTitle => '加入穿搭';

  @override
  String get newOutfitGroup => '新增穿搭';

  @override
  String get currentOutfitLabel => '目前穿搭';

  @override
  String get accessoriesLabel => '配件';

  @override
  String get optionalLabel => '選填';

  @override
  String get createOutfit => '建立造型';

  @override
  String get createOutfitHint => '使用這些單品建立另一套穿搭造型';

  @override
  String get backgroundLabel => '背景';

  @override
  String get noneLabel => '無';

  @override
  String selectItemTitle(String item) {
    return '選擇$item';
  }

  @override
  String get notSelected => '尚未選擇';

  @override
  String get loadingGarments => '載入服飾中…';

  @override
  String get myCollection => '我的收藏';

  @override
  String get myOutfit => '我的穿搭';

  @override
  String get yourOutfitLabel => '你的穿搭';

  @override
  String get shareComingSoon => '分享功能即將推出';

  @override
  String get failedToLoadImage => '圖片載入失敗';

  @override
  String get failedToLoadGarments => '服飾載入失敗';

  @override
  String get saveOutfitPromptTitle => '要儲存這件穿搭嗎？';

  @override
  String get saveOutfitPromptBody => '如果不儲存，這件穿搭將會被刪除。';

  @override
  String get deleteOutfitTitle => '刪除穿搭';

  @override
  String get deleteOutfitConfirmation => '確定要刪除這個版本嗎？';

  @override
  String get deleteOutfitGroupConfirmation => '這麼做也會一併刪除跟這套穿搭同批產生的其他穿搭，且無法復原。';

  @override
  String get deleteThisVersion => '刪除版本';

  @override
  String get outfitUpdateFailed => '无法更新这套穿搭，请再试一次。';

  @override
  String get outfitDeleteFailed => '无法删除这套穿搭，请再试一次。';

  @override
  String get outfitCopyFailed => '无法复制这套穿搭，请再试一次。';

  @override
  String createdOnDate(String date) {
    return '建立於 $date';
  }

  @override
  String outfitTitle(String style) {
    return '$style穿搭';
  }

  @override
  String get outfitDetailsTitle => '穿搭詳情';

  @override
  String get tripDetailsTitle => '行程詳情';

  @override
  String get clothingDetailsTitle => '衣物詳情';

  @override
  String garmentsCount(int count) {
    return '服飾（$count）';
  }

  @override
  String get styleMinimal => '極簡 / 無印感';

  @override
  String get styleClassic => '經典';

  @override
  String get styleStreetwear => '街頭';

  @override
  String get styleSmartCasual => '質感休閒';

  @override
  String get styleAthleisure => '運動休閒';

  @override
  String get styleVintage => '復古';

  @override
  String get styleWorkwear => '工裝';

  @override
  String get stylePreppy => '學院';

  @override
  String get styleBusiness => '商務';

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
  String get explore => '探索';

  @override
  String get exploreComingSoon => '即將推出';

  @override
  String get notifications => '通知';

  @override
  String get exploreNavForYou => '為你推薦';

  @override
  String get exploreNavSearch => '搜尋';

  @override
  String get exploreNavBag => '購物袋';

  @override
  String get exploreNavSaved => '收藏';

  @override
  String get finishOutfit => '完成穿搭';

  @override
  String get finishOutfitPromptBody => '讓 AI 補完你已選的單品。';

  @override
  String get finishWithAi => '使用 AI 完成';

  @override
  String get occasionFieldLabel => '場合';

  @override
  String get temperatureFieldLabel => '溫度';

  @override
  String get completeWithAiUnavailable => 'AI 無法完成穿搭建議，請稍後再試。';

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
  String get photoSourceDialogSubtitle => '你想怎麼新增照片？';

  @override
  String get quickActionAddOutfit => '建立穿搭';

  @override
  String get newTrip => '規劃行程';

  @override
  String get useSharedPhotoTitle => '使用這張照片';

  @override
  String get useSharedPhotoSubtitle => '你想怎麼使用這張照片？';

  @override
  String get retry => '重試';

  @override
  String get aiTag => 'AI';

  @override
  String get matchALookTitle => '比對穿搭';

  @override
  String get matchALookSubtitle => '上傳一張照片，讓我們從你的衣櫃中找出相似的單品。';

  @override
  String get matchingLookEllipsis => '正在比對你的穿搭...';

  @override
  String get matchALookFailed => '無法比對這張照片，請再試一次。';

  @override
  String get matchALookNoPerson => '這張照片中找不到人物，請換一張試試。';

  @override
  String get matchALookMultiplePeople => '這張照片中有一個以上的人，請用只有你一個人的照片。';

  @override
  String get matchALookOutfitUnclear => '無法清楚辨識照片中的穿搭，請換一張沒有遮擋、更清楚的照片。';

  @override
  String get matchALookInsufficientCloset => '請先在衣櫃中新增幾件單品，再使用比對穿搭功能。';

  @override
  String get noCloseMatch => '沒有相近的單品';

  @override
  String get referenceLookLabel => '參考穿搭';

  @override
  String piecesMatchedCount(int count) {
    return '已比對 $count 件';
  }

  @override
  String get change => '更換';

  @override
  String get removeReferenceLook => '移除參考穿搭';

  @override
  String get editPhoto => '編輯照片';

  @override
  String noOptionsAvailable(String label) {
    return '沒有可用的$label';
  }

  @override
  String get filterAll => '全部';

  @override
  String get editTripName => '編輯名稱';

  @override
  String get editDestinations => '編輯目的地';

  @override
  String get enterTripName => '輸入行程名稱';

  @override
  String get deleteTrip => '刪除行程';

  @override
  String get deleteTripConfirmation => '確定要刪除這個行程嗎？';

  @override
  String get viewPlan => '查看行程';

  @override
  String get tripNameLabel => '行程名稱';

  @override
  String get tripNameHint => '例如：日本春季之旅';

  @override
  String get destinationAndDatesLabel => '目的地與日期';

  @override
  String get create => '建立';

  @override
  String get regenerate => '重新產生';

  @override
  String get regenerateOutfitConfirmTitle => '要重新產生這張圖片嗎?';

  @override
  String get regenerateOutfitConfirmBody => '系統會以相同的服裝重新用 AI 算圖,並取代目前的圖片。';

  @override
  String get setAsCover => '設為代表圖';

  @override
  String get letUwearisPlanOutfits => '讓 Uwearis 規劃你的行程穿搭';

  @override
  String get letUwearisPlanOutfitsHint => 'Uwearis 會根據你行李箱裡的衣物，為每一天安排一套穿搭。';

  @override
  String get planTripOutfits => '規劃行程穿搭';

  @override
  String get replanTripOutfits => '重新規劃行程穿搭';

  @override
  String get replanTripOutfitsTitle => '要重新規劃行程穿搭嗎？';

  @override
  String get replanTripOutfitsBody => '手動調整過或已經有照片的穿搭會保留；使用了已移出行李箱衣物的穿搭則會重新規劃。';

  @override
  String get replan => '重新規劃';

  @override
  String get noOutfitsNeedReplan => '沒有需要重新規劃的穿搭——目前的行李箱內容都還適用。';

  @override
  String get failedToGeneratePlan => '規劃穿搭失敗';

  @override
  String get generatingPlanEllipsis => '規劃穿搭中…';

  @override
  String get failedToUpdateDayOutfit => '更新穿搭失敗';

  @override
  String get failedToGenerateOutfit => '產生穿搭失敗';

  @override
  String get regenerateOutfit => '重新產生穿搭';

  @override
  String get changeGarments => '更換單品';

  @override
  String get noOutfitPlannedYetTitle => '尚未安排穿搭';

  @override
  String get noOutfitPlannedYetHint => '產生行程穿搭計畫，為這一天安排服裝。';

  @override
  String missingFromSuitcaseCount(int count) {
    return '還有 $count 件尚未打包。';
  }

  @override
  String suitcaseItemStillUsedCount(int count) {
    return '已從行李箱移除。這件衣物仍被本次行程中 $count 套穿搭方案使用。';
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
  String get dayOutfitMissingCoreItemsMessage => '這套穿搭還缺少上衣、下身或鞋子，請先補齊才能產生。';

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
  String get addLocation => '新增目的地';

  @override
  String get camera => '拍照';

  @override
  String get switchCamera => '切換鏡頭';

  @override
  String get takePhotoLabel => '相機';

  @override
  String get chooseFromAlbumLabel => '相簿';

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
  String get colorCharcoal => '深灰';

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
  String get garmentRenameFailed => '无法重新命名，请再试一次。';

  @override
  String get garmentSaveFailed => '无法保存，请再试一次。';

  @override
  String get garmentDeleteFailed => '无法删除，请再试一次。';

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
  String get purchasedLabel => '購買日';

  @override
  String get analyzeWithAi => 'AI 分析';

  @override
  String get analyzeAgain => '重新分析';

  @override
  String get closetAnalysisFailed => '分析失敗，請再試一次。';

  @override
  String get closetAnalysisGarmentNotFound => '在你的衣櫃中找不到這件單品了。';

  @override
  String get versatilityDescription => '這件單品跟你衣櫃的搭配度。';

  @override
  String versatilityLevelValue(int level) {
    return '等級 $level';
  }

  @override
  String get versatilityBandVeryLimited => '非常有限';

  @override
  String get versatilityBandLimited => '有限';

  @override
  String get versatilityBandModerate => '普通';

  @override
  String get versatilityBandVersatile => '百搭';

  @override
  String get versatilityBandHighlyVersatile => '高度百搭';

  @override
  String get outfitIdeasHeading => '穿搭靈感';

  @override
  String get similarInClosetHeading => '衣櫃中的相似單品';

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
  String get purchaseDateLabel => '購買日期（選填）';

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
  String get noOutfitsYet => '尚無穿搭';

  @override
  String get outfitsEmptyHint => '從衣櫃搭配單品，組成一套完整穿搭。';

  @override
  String get itemNotUsedInOutfitsYet => '這件單品尚未用於任何穿搭。';

  @override
  String get failedToUpdateFavorite => '更新收藏失敗';

  @override
  String get garmentRemovedFromClosetNotice => '這件衣物已從衣櫥中移除。';

  @override
  String get addBackToCloset => '加回衣櫥';

  @override
  String get failedToRestoreGarment => '還原這件衣物失敗';

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
  String get tripsEmptyHint => '規劃一趟旅程，讓 Uwearis 幫你打包行李、安排每日穿搭。';

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
  String get packingAdviceLabel => '打包建議';

  @override
  String get suitcaseLabel => '行李箱';

  @override
  String get packClothingHint => '為這趟行程打包衣物';

  @override
  String get selectGarmentsTitle => '選擇衣物';

  @override
  String get editOutfitTitle => '編輯穿搭';

  @override
  String get editGarmentTitle => '編輯衣物';

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
  String get noGarmentsInCloset => '衣櫃中沒有衣物';

  @override
  String get closetEmptyCategoryHint => '從這個分類新增衣物，充實你的衣櫃。';

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
  String get loadingSuitcaseEllipsis => '載入行李箱中…';

  @override
  String get updatingSuitcaseEllipsis => '更新行李箱中…';

  @override
  String get addGarment => '新增衣物';

  @override
  String get browseYourClosetHint => '瀏覽你的衣櫃';

  @override
  String get addAction => '新增';

  @override
  String get startPackingTripTitle => '開始打包你的行程';

  @override
  String get startPackingTripHint => '從衣櫃挑選衣物，打造你的行程穿搭。';

  @override
  String get addGarmentsButton => '新增衣物';

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
  String get comfortAdjustment => '體感溫度調整';

  @override
  String get weeklySchedule => '每週排程';

  @override
  String get perceivedTempOffset => '偏移量';

  @override
  String get lifestyleDescription => '告訴 Uwearis 你的作息與舒適度偏好，讓每日穿搭建議更貼近你。';

  @override
  String get weeklyScheduleIntro => '設定你一週的典型作息。';

  @override
  String get comfortAdjustmentIntro => '微調你平常感受到的冷熱程度。';

  @override
  String selectOccasionTitle(String day) {
    return '選擇$day的場合';
  }

  @override
  String get todaysOutfit => '今日穿搭';

  @override
  String get latestOutfitTitle => '你的最新穿搭';

  @override
  String get dailyOutfitsUnlockTitle => '解鎖每日穿搭';

  @override
  String get dailyOutfitsUnlockBody => '再幫衣櫃新增幾件單品。';

  @override
  String get dailyOutfitsUnlockedTitle => '每日穿搭已解鎖';

  @override
  String get dailyOutfitsUnlockedBody => '你的衣櫃已經準備好,每天都能為你搭配專屬穿搭。';

  @override
  String get getFirstDailyOutfitButton => '產生我的第一套穿搭';

  @override
  String get loadingWeatherEllipsis => '載入天氣中…';

  @override
  String get viewDetails => '查看詳情';

  @override
  String get gettingStartedSectionLabel => '開始使用';

  @override
  String get gettingStartedWelcomeTitle => '歡迎使用 Uwearis';

  @override
  String get gettingStartedWelcomeSubtitle => '設定你的個人資料並建立衣櫥，解鎖專屬的穿搭預覽。';

  @override
  String get gettingStartedProfilePhotoLabel => '個人照片';

  @override
  String get gettingStartedFullBodyPhotoLabel => '全身照片';

  @override
  String get gettingStartedGetStartedButton => '開始設定';

  @override
  String get gettingStartedAboutYouLabel => '個人資料';

  @override
  String get continueLabel => '繼續';

  @override
  String get gettingStartedBuildClosetTitle => '打造你的衣櫥';

  @override
  String get gettingStartedBuildClosetSubtitle =>
      '新增一件上衣、一件下身和一雙鞋子，Uwearis 就能开始为你打造穿搭与个人化风格建议。';

  @override
  String get gettingStartedReadyForFirstLookTitle => '準備好打造第一套穿搭了嗎？';

  @override
  String get gettingStartedReadyForFirstLookSubtitle =>
      '你的衣櫥已經準備好了，建立第一套穿搭，看看穿在你身上的樣子。';

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
  String get loginFailed => '登录失败，请再试一次。';

  @override
  String get copyrightText => '版權所有 © Uwearis inc.';

  @override
  String get noItemsFound => '找不到項目。';

  @override
  String get edit => '編輯';

  @override
  String get analyzingClothingEllipsis => '分析衣物中…';

  @override
  String get analyzingEllipsis => '分析中…';

  @override
  String get analysisFailedTitle => '无法分析这张照片';

  @override
  String get analysisFailedBody => 'AI 分析没有完成，请检查网络连接后重试。';

  @override
  String get photoProcessingFailed => '无法处理这张照片，请换一张试试看。';

  @override
  String get reset => '重設';

  @override
  String get pinchToZoomHint => '用兩指縮放圖片，確保照片包含完整細節。';

  @override
  String get retake => '重拍';

  @override
  String get album => '相簿';

  @override
  String get heightHint => '身高';

  @override
  String get weightHint => '體重';

  @override
  String get feetLabel => '英尺';

  @override
  String get inchesLabel => '英寸';

  @override
  String get unitMetricLabel => '公制';

  @override
  String get unitImperialLabel => '英制';

  @override
  String get searchLocationTitle => '搜尋地點';

  @override
  String get cityNameHint => '城市名稱...';

  @override
  String get locationSearchFailed => '无法搜索该地点，请再试一次。';

  @override
  String get crashScreenTitle => '發生了一點問題';

  @override
  String get crashScreenMessage => '請重新啟動 App，若問題持續請聯繫客服。';

  @override
  String get sessionExpiredTitle => '登入已過期';

  @override
  String get sessionExpiredMessage => '您的登入已過期，請重新登入以繼續使用。';

  @override
  String get errorDialogTitle => '錯誤';

  @override
  String get ok => '確定';

  @override
  String get googleLoginMissingToken => 'Google 登入失敗：缺少身份權杖';

  @override
  String get appleLoginMissingToken => 'Apple 登入失敗：缺少身份權杖';

  @override
  String get unknownLocation => '未知地點';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appTitle => 'Uwearis';

  @override
  String get settings => '設定';

  @override
  String get account => '帳號';

  @override
  String get profilePhotoTitle => '個人頭像';

  @override
  String get aiModel => '試穿檔案';

  @override
  String get aiModelDescription => '新增參考照片，幫助 Uwearis 打造更精準的試穿效果。';

  @override
  String get faceReferenceLabel => '臉部參考';

  @override
  String get faceReferenceComingSoon => '即將推出';

  @override
  String get bodyReferenceLabel => '身形參考';

  @override
  String get bodyMeasurementsLabel => '身形數據';

  @override
  String get faceAppearanceSubtitle => '臉部、髮型與五官特徵';

  @override
  String get bodyProportionsSubtitle => '身形與整體比例';

  @override
  String get changePhotoAction => '更換照片';

  @override
  String get addPhotoAction => '新增照片';

  @override
  String get profileSaveFailed => '無法儲存個人資料，請再試一次。';

  @override
  String get photoUploadFailed => '照片上傳失敗，請再試一次。';

  @override
  String get faceReferenceNotFound => '臉部參考照片已失效，請重新上傳。';

  @override
  String get bodyReferenceNotFound => '身形參考照片已失效，請重新上傳。';

  @override
  String get fileNotFound => '所需的檔案已不存在，請重新上傳或再試一次。';

  @override
  String get faceReferenceLoadFailedTitle => '臉部參考照片無法載入';

  @override
  String get bodyReferenceLoadFailedTitle => '身形參考照片無法載入';

  @override
  String get referenceLoadFailedSubtitle => '請重新上傳照片';

  @override
  String get reuploadPhotoAction => '重新上傳';

  @override
  String get aiModelReady => '已就緒．臉部與身形皆已設定';

  @override
  String aiModelReferencesAdded(int count) {
    return '已新增 $count/2 項參考資料';
  }

  @override
  String get styleTaste => '風格品味';

  @override
  String get styleTasteDetailsLabel => '風格洞察';

  @override
  String get styleTasteSummary => 'Uwearis 學習你偏好的穿搭組合方式';

  @override
  String get styleTasteHeroSubtitle => '根據你收藏的穿搭與回饋，Uwearis 正在學習你的風格品味。';

  @override
  String get styleTasteDimensionsInfoTitle => '這些代表什麼';

  @override
  String get styleTasteRadarCardTitle => '你的風格品味';

  @override
  String get styleTasteRadarCardSubtitle => '你的風格偏好視覺化總覽。';

  @override
  String get styleProfileCardTitle => '風格分布';

  @override
  String get styleProfileCardSubtitle => '你的穿搭依風格的分布情況。';

  @override
  String get styleProfileOther => '其他';

  @override
  String styleTasteAnalysisStats(int count, int favoriteCount) {
    return '已分析 $count 套穿搭．$favoriteCount 套收藏';
  }

  @override
  String get lifestyle => '生活風格';

  @override
  String get logout => '登出';

  @override
  String get logoutConfirmTitle => '確定要登出嗎?';

  @override
  String get logoutConfirmBody => '登出後需要重新登入才能使用 Uwearis。';

  @override
  String get deleteAccount => '刪除帳號';

  @override
  String get deleteAccountConfirmTitle => '確定要刪除帳號嗎？';

  @override
  String get deleteAccountConfirmBody =>
      '這將永久刪除您的帳號與所有資料——穿搭、衣物、照片與偏好設定，且無法復原。';

  @override
  String get deletingAccount => '正在刪除帳號…';

  @override
  String get deleteAccountFailed => '刪除帳號失敗，請稍後再試。';

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
  String get save => '儲存';

  @override
  String get cancel => '取消';

  @override
  String get remove => '移除';

  @override
  String get rename => '重新命名';

  @override
  String get share => '分享';

  @override
  String get shareThisPiece => '分享這件單品';

  @override
  String get shareThisOutfit => '分享這套穿搭';

  @override
  String get shareImageUnavailable => '圖片載入失敗。';

  @override
  String get shareFailed => '分享失敗，請再試一次。';

  @override
  String get delete => '刪除';

  @override
  String get details => '詳情';

  @override
  String get renameOutfit => '重新命名穿搭';

  @override
  String get outfitNameLabel => '這套穿搭的名稱';

  @override
  String get addVersionButton => '新版本';

  @override
  String get addVersionTitle => '新增版本';

  @override
  String get versionLimitReachedTitle => '已達版本上限';

  @override
  String get versionLimitReachedBody => '每套穿搭最多可保留 10 個版本，請先刪除一個版本再新增。';

  @override
  String get addToMyOutfits => '加入我的穿搭';

  @override
  String get selectOutfitGroupTitle => '加入穿搭';

  @override
  String get newOutfitGroup => '新增穿搭';

  @override
  String get currentOutfitLabel => '目前穿搭';

  @override
  String get accessoriesLabel => '配件';

  @override
  String get optionalLabel => '選填';

  @override
  String get createOutfit => '建立造型';

  @override
  String get createOutfitHint => '使用這些單品建立另一套穿搭造型';

  @override
  String get backgroundLabel => '背景';

  @override
  String get noneLabel => '無';

  @override
  String selectItemTitle(String item) {
    return '選擇$item';
  }

  @override
  String get notSelected => '尚未選擇';

  @override
  String get loadingGarments => '載入服飾中…';

  @override
  String get myCollection => '我的收藏';

  @override
  String get myOutfit => '我的穿搭';

  @override
  String get yourOutfitLabel => '你的穿搭';

  @override
  String get shareComingSoon => '分享功能即將推出';

  @override
  String get failedToLoadImage => '圖片載入失敗';

  @override
  String get failedToLoadGarments => '服飾載入失敗';

  @override
  String get saveOutfitPromptTitle => '要儲存這件穿搭嗎？';

  @override
  String get saveOutfitPromptBody => '如果不儲存，這件穿搭將會被刪除。';

  @override
  String get deleteOutfitTitle => '刪除穿搭';

  @override
  String get deleteOutfitConfirmation => '確定要刪除這個版本嗎？';

  @override
  String get deleteOutfitGroupConfirmation => '這麼做也會一併刪除跟這套穿搭同批產生的其他穿搭，且無法復原。';

  @override
  String get deleteThisVersion => '刪除版本';

  @override
  String get outfitUpdateFailed => '無法更新這套穿搭，請再試一次。';

  @override
  String get outfitDeleteFailed => '無法刪除這套穿搭，請再試一次。';

  @override
  String get outfitCopyFailed => '無法複製這套穿搭，請再試一次。';

  @override
  String createdOnDate(String date) {
    return '建立於 $date';
  }

  @override
  String outfitTitle(String style) {
    return '$style穿搭';
  }

  @override
  String get outfitDetailsTitle => '穿搭詳情';

  @override
  String get tripDetailsTitle => '行程詳情';

  @override
  String get clothingDetailsTitle => '衣物詳情';

  @override
  String garmentsCount(int count) {
    return '服飾（$count）';
  }

  @override
  String get styleMinimal => '極簡 / 無印感';

  @override
  String get styleClassic => '經典';

  @override
  String get styleStreetwear => '街頭';

  @override
  String get styleSmartCasual => '質感休閒';

  @override
  String get styleAthleisure => '運動休閒';

  @override
  String get styleVintage => '復古';

  @override
  String get styleWorkwear => '工裝';

  @override
  String get stylePreppy => '學院';

  @override
  String get styleBusiness => '商務';

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
  String get explore => '探索';

  @override
  String get exploreComingSoon => '即將推出';

  @override
  String get notifications => '通知';

  @override
  String get exploreNavForYou => '為你推薦';

  @override
  String get exploreNavSearch => '搜尋';

  @override
  String get exploreNavBag => '購物袋';

  @override
  String get exploreNavSaved => '收藏';

  @override
  String get finishOutfit => '完成穿搭';

  @override
  String get finishOutfitPromptBody => '讓 AI 補完你已選的單品。';

  @override
  String get finishWithAi => '使用 AI 完成';

  @override
  String get occasionFieldLabel => '場合';

  @override
  String get temperatureFieldLabel => '溫度';

  @override
  String get completeWithAiUnavailable => 'AI 無法完成穿搭建議，請稍後再試。';

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
  String get photoSourceDialogSubtitle => '你想怎麼新增照片？';

  @override
  String get quickActionAddOutfit => '建立穿搭';

  @override
  String get newTrip => '規劃行程';

  @override
  String get useSharedPhotoTitle => '使用這張照片';

  @override
  String get useSharedPhotoSubtitle => '你想怎麼使用這張照片？';

  @override
  String get retry => '重試';

  @override
  String get aiTag => 'AI';

  @override
  String get matchALookTitle => '比對穿搭';

  @override
  String get matchALookSubtitle => '上傳一張照片，讓我們從你的衣櫃中找出相似的單品。';

  @override
  String get matchingLookEllipsis => '正在比對你的穿搭...';

  @override
  String get matchALookFailed => '無法比對這張照片，請再試一次。';

  @override
  String get matchALookNoPerson => '這張照片中找不到人物，請換一張試試。';

  @override
  String get matchALookMultiplePeople => '這張照片中有一個以上的人，請用只有你一個人的照片。';

  @override
  String get matchALookOutfitUnclear => '無法清楚辨識照片中的穿搭，請換一張沒有遮擋、更清楚的照片。';

  @override
  String get matchALookInsufficientCloset => '請先在衣櫃中新增幾件單品，再使用比對穿搭功能。';

  @override
  String get noCloseMatch => '沒有相近的單品';

  @override
  String get referenceLookLabel => '參考穿搭';

  @override
  String piecesMatchedCount(int count) {
    return '已比對 $count 件';
  }

  @override
  String get change => '更換';

  @override
  String get removeReferenceLook => '移除參考穿搭';

  @override
  String get editPhoto => '編輯照片';

  @override
  String noOptionsAvailable(String label) {
    return '沒有可用的$label';
  }

  @override
  String get filterAll => '全部';

  @override
  String get editTripName => '編輯名稱';

  @override
  String get editDestinations => '編輯目的地';

  @override
  String get enterTripName => '輸入行程名稱';

  @override
  String get deleteTrip => '刪除行程';

  @override
  String get deleteTripConfirmation => '確定要刪除這個行程嗎？';

  @override
  String get viewPlan => '查看行程';

  @override
  String get tripNameLabel => '行程名稱';

  @override
  String get tripNameHint => '例如：日本春季之旅';

  @override
  String get destinationAndDatesLabel => '目的地與日期';

  @override
  String get create => '建立';

  @override
  String get regenerate => '重新產生';

  @override
  String get regenerateOutfitConfirmTitle => '要重新產生這張圖片嗎?';

  @override
  String get regenerateOutfitConfirmBody => '系統會以相同的服裝重新用 AI 算圖,並取代目前的圖片。';

  @override
  String get setAsCover => '設為代表圖';

  @override
  String get letUwearisPlanOutfits => '讓 Uwearis 規劃你的行程穿搭';

  @override
  String get letUwearisPlanOutfitsHint => 'Uwearis 會根據你行李箱裡的衣物，為每一天安排一套穿搭。';

  @override
  String get planTripOutfits => '規劃行程穿搭';

  @override
  String get replanTripOutfits => '重新規劃行程穿搭';

  @override
  String get replanTripOutfitsTitle => '要重新規劃行程穿搭嗎？';

  @override
  String get replanTripOutfitsBody => '手動調整過或已經有照片的穿搭會保留；使用了已移出行李箱衣物的穿搭則會重新規劃。';

  @override
  String get replan => '重新規劃';

  @override
  String get noOutfitsNeedReplan => '沒有需要重新規劃的穿搭——目前的行李箱內容都還適用。';

  @override
  String get failedToGeneratePlan => '規劃穿搭失敗';

  @override
  String get generatingPlanEllipsis => '規劃穿搭中…';

  @override
  String get failedToUpdateDayOutfit => '更新穿搭失敗';

  @override
  String get failedToGenerateOutfit => '產生穿搭失敗';

  @override
  String get regenerateOutfit => '重新產生穿搭';

  @override
  String get changeGarments => '更換單品';

  @override
  String get noOutfitPlannedYetTitle => '尚未安排穿搭';

  @override
  String get noOutfitPlannedYetHint => '產生行程穿搭計畫，為這一天安排服裝。';

  @override
  String missingFromSuitcaseCount(int count) {
    return '還有 $count 件尚未打包。';
  }

  @override
  String suitcaseItemStillUsedCount(int count) {
    return '已從行李箱移除。這件衣物仍被本次行程中 $count 套穿搭方案使用。';
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
  String get dayOutfitMissingCoreItemsMessage => '這套穿搭還缺少上衣、下身或鞋子，請先補齊才能產生。';

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
  String get addLocation => '新增目的地';

  @override
  String get camera => '拍照';

  @override
  String get switchCamera => '切換鏡頭';

  @override
  String get takePhotoLabel => '相機';

  @override
  String get chooseFromAlbumLabel => '相簿';

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
  String get colorCharcoal => '深灰';

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
  String get garmentRenameFailed => '無法重新命名，請再試一次。';

  @override
  String get garmentSaveFailed => '無法儲存，請再試一次。';

  @override
  String get garmentDeleteFailed => '無法刪除，請再試一次。';

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
  String get purchasedLabel => '購買日';

  @override
  String get analyzeWithAi => 'AI 分析';

  @override
  String get analyzeAgain => '重新分析';

  @override
  String get closetAnalysisFailed => '分析失敗，請再試一次。';

  @override
  String get closetAnalysisGarmentNotFound => '在你的衣櫃中找不到這件單品了。';

  @override
  String get versatilityDescription => '這件單品跟你衣櫃的搭配度。';

  @override
  String versatilityLevelValue(int level) {
    return '等級 $level';
  }

  @override
  String get versatilityBandVeryLimited => '非常有限';

  @override
  String get versatilityBandLimited => '有限';

  @override
  String get versatilityBandModerate => '普通';

  @override
  String get versatilityBandVersatile => '百搭';

  @override
  String get versatilityBandHighlyVersatile => '高度百搭';

  @override
  String get outfitIdeasHeading => '穿搭靈感';

  @override
  String get similarInClosetHeading => '衣櫃中的相似單品';

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
  String get purchaseDateLabel => '購買日期（選填）';

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
  String get noOutfitsYet => '尚無穿搭';

  @override
  String get outfitsEmptyHint => '從衣櫃搭配單品，組成一套完整穿搭。';

  @override
  String get itemNotUsedInOutfitsYet => '這件單品尚未用於任何穿搭。';

  @override
  String get failedToUpdateFavorite => '更新收藏失敗';

  @override
  String get garmentRemovedFromClosetNotice => '這件衣物已從衣櫥中移除。';

  @override
  String get addBackToCloset => '加回衣櫥';

  @override
  String get failedToRestoreGarment => '還原這件衣物失敗';

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
  String get tripsEmptyHint => '規劃一趟旅程，讓 Uwearis 幫你打包行李、安排每日穿搭。';

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
  String get packingAdviceLabel => '打包建議';

  @override
  String get suitcaseLabel => '行李箱';

  @override
  String get packClothingHint => '為這趟行程打包衣物';

  @override
  String get selectGarmentsTitle => '選擇衣物';

  @override
  String get editOutfitTitle => '編輯穿搭';

  @override
  String get editGarmentTitle => '編輯衣物';

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
  String get noGarmentsInCloset => '衣櫃中沒有衣物';

  @override
  String get closetEmptyCategoryHint => '從這個分類新增衣物，充實你的衣櫃。';

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
  String get loadingSuitcaseEllipsis => '載入行李箱中…';

  @override
  String get updatingSuitcaseEllipsis => '更新行李箱中…';

  @override
  String get addGarment => '新增衣物';

  @override
  String get browseYourClosetHint => '瀏覽你的衣櫃';

  @override
  String get addAction => '新增';

  @override
  String get startPackingTripTitle => '開始打包你的行程';

  @override
  String get startPackingTripHint => '從衣櫃挑選衣物，打造你的行程穿搭。';

  @override
  String get addGarmentsButton => '新增衣物';

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
  String get comfortAdjustment => '體感溫度調整';

  @override
  String get weeklySchedule => '每週排程';

  @override
  String get perceivedTempOffset => '偏移量';

  @override
  String get lifestyleDescription => '告訴 Uwearis 你的作息與舒適度偏好，讓每日穿搭建議更貼近你。';

  @override
  String get weeklyScheduleIntro => '設定你一週的典型作息。';

  @override
  String get comfortAdjustmentIntro => '微調你平常感受到的冷熱程度。';

  @override
  String selectOccasionTitle(String day) {
    return '選擇$day的場合';
  }

  @override
  String get todaysOutfit => '今日穿搭';

  @override
  String get latestOutfitTitle => '你的最新穿搭';

  @override
  String get dailyOutfitsUnlockTitle => '解鎖每日穿搭';

  @override
  String get dailyOutfitsUnlockBody => '再幫衣櫃新增幾件單品。';

  @override
  String get dailyOutfitsUnlockedTitle => '每日穿搭已解鎖';

  @override
  String get dailyOutfitsUnlockedBody => '你的衣櫃已經準備好,每天都能為你搭配專屬穿搭。';

  @override
  String get getFirstDailyOutfitButton => '產生我的第一套穿搭';

  @override
  String get loadingWeatherEllipsis => '載入天氣中…';

  @override
  String get viewDetails => '查看詳情';

  @override
  String get gettingStartedSectionLabel => '開始使用';

  @override
  String get gettingStartedWelcomeTitle => '歡迎使用 Uwearis';

  @override
  String get gettingStartedWelcomeSubtitle => '設定你的個人資料並建立衣櫥，解鎖專屬的穿搭預覽。';

  @override
  String get gettingStartedProfilePhotoLabel => '個人照片';

  @override
  String get gettingStartedFullBodyPhotoLabel => '全身照片';

  @override
  String get gettingStartedGetStartedButton => '開始設定';

  @override
  String get gettingStartedAboutYouLabel => '個人資料';

  @override
  String get continueLabel => '繼續';

  @override
  String get gettingStartedBuildClosetTitle => '打造你的衣櫥';

  @override
  String get gettingStartedBuildClosetSubtitle =>
      '新增一件上衣、一件下身和一雙鞋子，Uwearis 就能開始為你打造穿搭與個人化風格建議。';

  @override
  String get gettingStartedReadyForFirstLookTitle => '準備好打造第一套穿搭了嗎？';

  @override
  String get gettingStartedReadyForFirstLookSubtitle =>
      '你的衣櫥已經準備好了，建立第一套穿搭，看看穿在你身上的樣子。';

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
  String get loginFailed => '登入失敗，請再試一次。';

  @override
  String get copyrightText => '版權所有 © Uwearis inc.';

  @override
  String get noItemsFound => '找不到項目。';

  @override
  String get edit => '編輯';

  @override
  String get analyzingClothingEllipsis => '分析衣物中…';

  @override
  String get analyzingEllipsis => '分析中…';

  @override
  String get analysisFailedTitle => '無法分析這張照片';

  @override
  String get analysisFailedBody => 'AI 分析沒有完成，請檢查網路連線後重試。';

  @override
  String get photoProcessingFailed => '無法處理這張照片，請換一張試試看。';

  @override
  String get reset => '重設';

  @override
  String get pinchToZoomHint => '用兩指縮放圖片，確保照片包含完整細節。';

  @override
  String get retake => '重拍';

  @override
  String get album => '相簿';

  @override
  String get heightHint => '身高';

  @override
  String get weightHint => '體重';

  @override
  String get feetLabel => '英尺';

  @override
  String get inchesLabel => '英寸';

  @override
  String get unitMetricLabel => '公制';

  @override
  String get unitImperialLabel => '英制';

  @override
  String get searchLocationTitle => '搜尋地點';

  @override
  String get cityNameHint => '城市名稱...';

  @override
  String get locationSearchFailed => '無法搜尋該地點，請再試一次。';

  @override
  String get crashScreenTitle => '發生了一點問題';

  @override
  String get crashScreenMessage => '請重新啟動 App，若問題持續請聯繫客服。';

  @override
  String get sessionExpiredTitle => '登入已過期';

  @override
  String get sessionExpiredMessage => '您的登入已過期，請重新登入以繼續使用。';

  @override
  String get errorDialogTitle => '錯誤';

  @override
  String get ok => '確定';

  @override
  String get googleLoginMissingToken => 'Google 登入失敗：缺少身份權杖';

  @override
  String get appleLoginMissingToken => 'Apple 登入失敗：缺少身份權杖';

  @override
  String get unknownLocation => '未知地點';
}
