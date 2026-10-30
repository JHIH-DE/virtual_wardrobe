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
  String get accountSummary => '個人資料與安全性';

  @override
  String get profilePhotoTitle => '個人頭像';

  @override
  String get myVirtualModelTitle => '我的虚拟模特';

  @override
  String get myVirtualModelDescription => '新增脸部照片与全身照，建立您的虚拟模特。';

  @override
  String get myOutfitProfileTitle => '个人穿搭档案';

  @override
  String get myOutfitProfileSummary => '试穿模特与体感温度';

  @override
  String get temperatureAdjustmentTitle => '穿搭保暖度';

  @override
  String get temperatureAdjustmentDescription => '依照你的舒适度，调整每日穿搭推荐。';

  @override
  String get temperatureAdjustmentLighter => '较轻薄';

  @override
  String get temperatureAdjustmentWarmer => '较保暖';

  @override
  String get facePhotoLabel => '脸部照片';

  @override
  String get faceReferenceComingSoon => '即將推出';

  @override
  String get fullBodyPhotoLabel => '全身照片';

  @override
  String get bodyMeasurementsLabel => '身形數據';

  @override
  String get addPhotoAction => '新增照片';

  @override
  String get profileSaveFailed => '无法保存个人资料，请再试一次。';

  @override
  String get photoUploadFailed => '照片上传失败，请再试一次。';

  @override
  String get facePhotoNotFound => '脸部照片已失效，请重新上传。';

  @override
  String get fullBodyPhotoNotFound => '全身照片已失效，请重新上传。';

  @override
  String get fileNotFound => '所需文件已不存在，请重新上传或再试一次。';

  @override
  String dailyGenerationLimitReached(String time) {
    return '今天的 AI 试穿次数已经用完，将在 $time 重置。';
  }

  @override
  String get errorNoConnection => '目前没有网络连接，请检查网络后重试。';

  @override
  String get errorTooManyRequests => '操作过于频繁，请稍等一下再试。';

  @override
  String tryOnStillRendering(String action) {
    return '这次生成比平常久，可能还在处理中。稍等一下再按一次「$action」；如果已经完成，会直接显示结果，不会再生成一次。';
  }

  @override
  String get facePhotoLoadFailedTitle => '脸部照片无法加载';

  @override
  String get fullBodyPhotoLoadFailedTitle => '全身照片无法加载';

  @override
  String get photoLoadFailedSubtitle => '请重新上传照片';

  @override
  String get reuploadPhotoAction => '重新上传';

  @override
  String get virtualModelSectionTitle => '试穿模特';

  @override
  String get virtualModelSectionSubtitle => '用于生成你的虚拟试穿图片。';

  @override
  String get virtualModelGenerateRequiresBodyRefHint => '请先添加全身照片。';

  @override
  String get virtualModelGenerateAction => '生成';

  @override
  String get virtualModelGenerateNewAction => '生成新的合成照';

  @override
  String get virtualModelGenerateConfirmTitle => '要生成虚拟模特吗？';

  @override
  String get virtualModelGenerateConfirmBody => '系统将以目前的照片重新生成虚拟模特，并取代先前的版本。';

  @override
  String get virtualModelGenerateFailed => '虚拟模特生成失败，请稍后再试。';

  @override
  String get styleTaste => '風格品味';

  @override
  String get styleTasteDetailsLabel => '風格洞察';

  @override
  String get styleTasteSummary => '你的穿搭偏好';

  @override
  String get styleTasteLockedSummary => '建立穿搭後即可使用';

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
  String get logout => '登出';

  @override
  String get logoutConfirmTitle => '確定要登出嗎?';

  @override
  String get logoutConfirmBody => '登出後需要重新登入才能使用 Uwearis。';

  @override
  String get deleteAccount => '刪除帳號';

  @override
  String get tierGold => '金牌';

  @override
  String get tierSilver => '銀牌';

  @override
  String get tierBronze => '銅牌';

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
  String get addVersionButton => '新增版本';

  @override
  String get addVersionTitle => '新增版本';

  @override
  String get versionLimitReachedTitle => '已達版本上限';

  @override
  String get versionLimitReachedBody => '每套穿搭最多可保留 10 個版本，請先刪除一個版本再新增。';

  @override
  String get currentOutfitLabel => '目前穿搭';

  @override
  String get accessoriesLabel => '配件';

  @override
  String get optionalLabel => '選填';

  @override
  String get createOutfit => '建立造型';

  @override
  String get createVersion => '建立版本';

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
  String get outfitItemsLabel => '你的穿搭';

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
  String get finishOutfit => 'AI 造型';

  @override
  String get finishOutfitDescription => '讓 AI 幫你完成穿搭。';

  @override
  String get finishWithAi => '開始';

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
  String get editItinerary => '編輯行程';

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
  String get itineraryAndDatesLabel => '行程與日期';

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
  String get letUwearisPlanOutfitsHint =>
      'Uwearis 会用行李箱里的衣物搭出几套穿搭，旅途中依当天心情自由挑选。';

  @override
  String get planTripOutfits => '規劃行程穿搭';

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
  String get addLocation => '新增行程';

  @override
  String get camera => '拍照';

  @override
  String get switchCamera => '切換鏡頭';

  @override
  String get cameraUnavailable => '无法打开相机';

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
  String get garmentSaveFailed => '无法保存，请再试一次。';

  @override
  String get garmentDeleteFailed => '无法删除，请再试一次。';

  @override
  String get unsavedChangesTitle => '你有未儲存的變更';

  @override
  String get unsavedChangesBody => '如果離開此頁面，你的變更將會遺失。';

  @override
  String get autoSaveFailedLeaveBody => '最新的變更未能儲存。如果現在離開，這些變更將會遺失。';

  @override
  String get savingEllipsis => '儲存中…';

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
  String get closetMatch => '衣櫥匹配度';

  @override
  String get viewClosetMatch => '查看衣櫥匹配度';

  @override
  String get viewMatch => '查看匹配度';

  @override
  String get closetAnalysisFailed => '分析失敗，請再試一次。';

  @override
  String get closetAnalysisGarmentNotFound => '在你的衣櫃中找不到這件單品了。';

  @override
  String get versatilityDescription => '這件單品跟你衣櫃的搭配度。';

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
  String outfitIdeaNumber(int number) {
    return '穿搭 $number';
  }

  @override
  String get tryItOn => '試穿看看';

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
  String get fitSkinny => '緊身';

  @override
  String get fitSlim => '修身';

  @override
  String get fitRegular => '標準';

  @override
  String get fitRelaxed => '微寬鬆';

  @override
  String get fitOversized => '寬鬆';

  @override
  String get silhouetteLabel => '形狀';

  @override
  String get sleeveLengthLabel => '袖長';

  @override
  String get cropLengthLabel => '下身長度';

  @override
  String get silhouetteStraight => '直筒';

  @override
  String get silhouetteBoxy => '方正短寬';

  @override
  String get silhouetteLongline => '長版';

  @override
  String get silhouetteCropped => '短版';

  @override
  String get silhouetteCocoon => '繭型';

  @override
  String get silhouetteTapered => '錐形';

  @override
  String get silhouetteBalloon => '氣球褲';

  @override
  String get silhouetteJogger => '束口';

  @override
  String get silhouetteFlared => '喇叭／傘擺';

  @override
  String get silhouettePencil => '窄裙';

  @override
  String get silhouetteALine => 'A 字';

  @override
  String get silhouettePleated => '百褶';

  @override
  String get silhouetteShift => '直身';

  @override
  String get silhouetteFitAndFlare => '收腰傘擺';

  @override
  String get sleeveSleeveless => '無袖';

  @override
  String get sleeveShort => '短袖';

  @override
  String get sleeveThreeQuarter => '五分／七分袖';

  @override
  String get sleeveLong => '長袖';

  @override
  String get cropFullLength => '全長';

  @override
  String get cropNineLength => '九分';

  @override
  String get cropSevenLength => '七分';

  @override
  String get cropFiveLength => '五分';

  @override
  String get cropShorts => '短褲';

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
  String get usedInOutfits => '已用於穿搭';

  @override
  String usedInOutfitsCount(int count) {
    return '$count 套穿搭';
  }

  @override
  String get selectAColor => '選擇顏色';

  @override
  String get chooseColorTitle => '選擇顏色';

  @override
  String get chooseBackgroundTitle => '選擇背景';

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
  String get styleAuto => '自動';

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
  String get updatingTripEllipsis => '更新行程中…';

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
  String get thinkingEllipsis => '思考中…';

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
  String get addFromOutfit => '从已保存的穿搭新增';

  @override
  String get selectAnOutfitTitle => '選擇穿搭';

  @override
  String get selectVersionTitle => '選擇版本';

  @override
  String get allItemsAlreadyInSuitcase => '此版本的單品都已在行李箱中。';

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
  String suitcaseItemsCount(int count) {
    return '$count 件';
  }

  @override
  String get failedToUpdateSuitcase => '更新行李箱失敗';

  @override
  String get failedToRemoveItem => '移除項目失敗';

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
  String get todaysOutfit => '今日穿搭';

  @override
  String get latestOutfitTitle => '你的最新穿搭';

  @override
  String get loadingWeatherEllipsis => '載入天氣中…';

  @override
  String get viewDetails => '查看詳情';

  @override
  String get viewFullOutfit => '查看完整穿搭';

  @override
  String get gettingStartedSectionLabel => '開始使用';

  @override
  String get gettingStartedWelcomeTitle => '歡迎使用 Uwearis';

  @override
  String get gettingStartedWelcomeSubtitle => '設定你的個人資料並建立衣櫥，解鎖專屬的穿搭預覽。';

  @override
  String get gettingStartedGetStartedButton => '開始設定';

  @override
  String get gettingStartedNextButton => '下一步';

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
  String get loginTagline => '你的每日 AI 穿搭师';

  @override
  String loginTermsNotice(String terms, String privacy) {
    return '继续即表示你同意我们的$terms和$privacy。';
  }

  @override
  String get termsOfService => '服务条款';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get contactSupport => '联系客服';

  @override
  String get helpAndLegal => '帮助与法律信息';

  @override
  String appVersionLabel(String version) {
    return '版本 $version';
  }

  @override
  String get supportEmailSubject => 'Uwearis 客服';

  @override
  String supportEmailBody(String version, String device, String userId) {
    return '请在这行上方描述你遇到的问题。\n\n---\nApp 版本：$version\n设备：$device\n用户 ID：$userId';
  }

  @override
  String get openLinkFailed => '无法打开页面，请稍后再试。';

  @override
  String supportEmailCopied(String email) {
    return '无法打开邮件 App。已复制客服邮箱 $email，请粘贴到任意邮件 App 给我们发邮件。';
  }

  @override
  String get aiConsentTitle => 'AI 功能的数据使用说明';

  @override
  String aiConsentBody(String provider) {
    return '为了分析衣物、生成试穿图和规划穿搭，Uwearis 会把你提供的照片（衣物照、身形与脸部参考照、Match a Look 参考照）以及相关数据（衣物信息、身高体重、温度偏好、行程的地点、日期与天气）发送给第三方 AI 服务供应商（目前为 $provider）处理。你可以随时在 App 里删除照片或账号。';
  }

  @override
  String get aiConsentAgree => '同意并继续';

  @override
  String get aiConsentDecline => '暂不使用';

  @override
  String get continueWithApple => '使用 Apple 繼續';

  @override
  String get signInWithGoogle => '使用 Google 登入';

  @override
  String get signInWithFacebook => '使用 Facebook 登入';

  @override
  String get loginFailed => '登录失败，请再试一次。';

  @override
  String get copyrightText => '© Uwearis Inc. 版权所有';

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

  @override
  String get homeHeaderDatePattern => 'M月d日 EEEE';

  @override
  String get debugTools => '测试工具';

  @override
  String get debugToolsErrorDialogButton => '显示后端错误弹窗';

  @override
  String get debugToolsErrorDialogSummary => '预览收到后端错误时的弹窗';

  @override
  String get debugToolsSampleErrorMessage => '这是一条模拟的后端错误消息，用于预览错误弹窗的设计。';

  @override
  String get debugToolsComponentGallery => '组件展示';

  @override
  String get debugToolsComponentGallerySummary =>
      '按钮、卡片、标签与状态，含 1.0 / 1.3 / 2.0 文字缩放';

  @override
  String get debugToolsTestDartError => '发送测试错误';

  @override
  String get debugToolsTestDartErrorSummary =>
      '抛出未捕获的 Dart 例外，下次启动后会出现在 Crashlytics（仅限非 debug build）';

  @override
  String get debugToolsTestNativeCrash => '强制原生闪退';

  @override
  String get debugToolsTestNativeCrashSummary => '立即关闭 App，用来测试闪退符号化';

  @override
  String get createOutfitMissingItemsTitle => '还缺少单品';

  @override
  String get createOutfitMissingItemsBody => '加入以下单品，就能创建造型。';

  @override
  String get createOutfitMinGarmentsBody => '至少选择 2 件衣物，就能创建造型。';

  @override
  String get createVersionUnchangedTitle => '尚未做任何更改';

  @override
  String get createVersionUnchangedBody => '更换衣物或背景后，才能创建新版本。';

  @override
  String get yourTripOutfits => '你的旅行穿搭';

  @override
  String tripOutfitsSuggestedRange(int min, int max, int days) {
    return '$days 天的行程约需 $min–$max 套';
  }

  @override
  String get findMoreOutfits => 'AI 新增穿搭';

  @override
  String get refreshSuggestions => '更新 AI 推荐';

  @override
  String get refreshSuggestionsTitle => '要更新 AI 推荐吗？';

  @override
  String refreshSuggestionsBody(int count) {
    return 'Uwearis 会用新的组合取代 $count 套 AI 推荐。已保存、改过、保留或已试穿的穿搭都不会变动。';
  }

  @override
  String get refresh => '更新';

  @override
  String get noMoreTripOutfitCombinations => '目前的行李箱找不到更多合适的组合了。';

  @override
  String addedTripOutfitsCount(int count) {
    return '新增了 $count 套穿搭。';
  }

  @override
  String savedCandidatesAvailable(int count) {
    return '你有 $count 套穿搭适合这个行李箱，可以在下方加入。';
  }

  @override
  String get fromYourOutfits => '你的穿搭也适合';

  @override
  String get fromYourOutfitsHint => '需要的衣物都已经在行李箱里。';

  @override
  String get addToTrip => '加入旅行';

  @override
  String get tripOutfitsEmptyHint => '先把衣物或已保存的穿搭放进行李箱吧。';

  @override
  String get openSuitcase => '打开行李箱';

  @override
  String get tripOutfitSourceSaved => '已保存';

  @override
  String get tripOutfitSourceSuggested => 'AI 推荐';

  @override
  String get tripOutfitSourceManual => '自定义';

  @override
  String get tripOutfitKept => '已保留';

  @override
  String get keepOutfit => '保留穿搭';

  @override
  String get unkeepOutfit => '取消保留';

  @override
  String get removeFromTrip => '从旅行移除';

  @override
  String get removeTripOutfitTitle => '要从旅行移除吗？';

  @override
  String get removeTripOutfitBody => '这套穿搭会从这趟旅行移除，行李箱与已保存的穿搭都不会变动。';

  @override
  String tripOutfitFallbackName(int index) {
    return '穿搭 $index';
  }

  @override
  String missingGarmentsCount(int count) {
    return '缺少 $count 件衣物';
  }

  @override
  String get missingGarmentsDeletedHint => '有衣物已从衣柜删除，请编辑这套穿搭来替换。';

  @override
  String get tripOutfitAlreadyAdded => '已经加入这趟旅行';

  @override
  String get tripOutfitDuplicate => '这趟旅行已经有相同衣物的穿搭。';

  @override
  String get tripOutfitIncomplete => '穿搭需要上衣和下身（或连身服装），加上一双鞋。';

  @override
  String get tripOutfitGarmentNotPacked => '请选择行李箱里的衣物。';

  @override
  String get tripOutfitLimitReached => '这趟旅行的穿搭已达上限。';

  @override
  String get tripOutfitGenerationInProgress => 'Uwearis 正在为这趟旅行搭配穿搭，请稍候。';

  @override
  String get savedOutfitUnavailable => '这套穿搭有衣物已从衣柜删除。';

  @override
  String get tripOutfitMissingGarmentsTryOn => '请先把缺少的衣物放回行李箱或编辑穿搭，再进行试穿。';

  @override
  String get failedToAddTripOutfit => '无法加入这套穿搭，请再试一次。';

  @override
  String get failedToRemoveTripOutfit => '无法移除这套穿搭，请再试一次。';

  @override
  String get addedOutfitToTrip => '已加入这趟旅行。';

  @override
  String addedOutfitToTripPacked(int count) {
    return '已加入这趟旅行，并打包了 $count 件衣物。';
  }

  @override
  String savedOutfitsInTripCount(int count) {
    return '已加入 $count 套';
  }

  @override
  String get tripOutfitEdited => '已编辑';

  @override
  String get itineraryTitle => '行程';

  @override
  String tripOutfitsCount(int count) {
    return '穿搭（$count）';
  }

  @override
  String get addTripOutfit => '手动新增';

  @override
  String get refreshAiButton => '更新 AI 穿搭';

  @override
  String tripOutfitsGoodVariety(int days) {
    return '$days 天的穿搭选择很充足';
  }

  @override
  String get tripOutfitsEmptyTitle => '还没有旅行穿搭';
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
  String get accountSummary => '個人資料與安全性';

  @override
  String get profilePhotoTitle => '個人頭像';

  @override
  String get myVirtualModelTitle => '我的虛擬模特兒';

  @override
  String get myVirtualModelDescription => '新增臉部照片與全身照，建立您的虛擬模特兒。';

  @override
  String get myOutfitProfileTitle => '個人穿搭檔案';

  @override
  String get myOutfitProfileSummary => '試穿模特兒與體感溫度';

  @override
  String get temperatureAdjustmentTitle => '穿搭保暖度';

  @override
  String get temperatureAdjustmentDescription => '依照你的舒適度，調整每日穿搭推薦。';

  @override
  String get temperatureAdjustmentLighter => '較輕薄';

  @override
  String get temperatureAdjustmentWarmer => '較保暖';

  @override
  String get facePhotoLabel => '臉部照片';

  @override
  String get faceReferenceComingSoon => '即將推出';

  @override
  String get fullBodyPhotoLabel => '全身照片';

  @override
  String get bodyMeasurementsLabel => '身形數據';

  @override
  String get addPhotoAction => '新增照片';

  @override
  String get profileSaveFailed => '無法儲存個人資料，請再試一次。';

  @override
  String get photoUploadFailed => '照片上傳失敗，請再試一次。';

  @override
  String get facePhotoNotFound => '臉部照片已失效，請重新上傳。';

  @override
  String get fullBodyPhotoNotFound => '全身照片已失效，請重新上傳。';

  @override
  String get fileNotFound => '所需的檔案已不存在，請重新上傳或再試一次。';

  @override
  String dailyGenerationLimitReached(String time) {
    return '今天的 AI 試穿次數已經用完，將在 $time 重置。';
  }

  @override
  String get errorNoConnection => '目前沒有網路連線，請確認網路後再試一次。';

  @override
  String get errorTooManyRequests => '操作太頻繁了，請稍等一下再試。';

  @override
  String tryOnStillRendering(String action) {
    return '這次生成比平常久，可能還在處理中。稍等一下再按一次「$action」；如果已經完成，會直接顯示結果，不會再生成一次。';
  }

  @override
  String get facePhotoLoadFailedTitle => '臉部照片無法載入';

  @override
  String get fullBodyPhotoLoadFailedTitle => '全身照片無法載入';

  @override
  String get photoLoadFailedSubtitle => '請重新上傳照片';

  @override
  String get reuploadPhotoAction => '重新上傳';

  @override
  String get virtualModelSectionTitle => '試穿模特兒';

  @override
  String get virtualModelSectionSubtitle => '用於生成你的虛擬試穿圖片。';

  @override
  String get virtualModelGenerateRequiresBodyRefHint => '請先新增全身照片。';

  @override
  String get virtualModelGenerateAction => '生成';

  @override
  String get virtualModelGenerateNewAction => '生成新的合成照';

  @override
  String get virtualModelGenerateConfirmTitle => '要生成虛擬模特兒嗎？';

  @override
  String get virtualModelGenerateConfirmBody => '系統將以目前的照片重新生成虛擬模特兒，並取代先前的版本。';

  @override
  String get virtualModelGenerateFailed => '虛擬模特兒生成失敗，請稍後再試。';

  @override
  String get styleTaste => '風格品味';

  @override
  String get styleTasteDetailsLabel => '風格洞察';

  @override
  String get styleTasteSummary => '你的穿搭偏好';

  @override
  String get styleTasteLockedSummary => '建立穿搭後即可使用';

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
  String get logout => '登出';

  @override
  String get logoutConfirmTitle => '確定要登出嗎?';

  @override
  String get logoutConfirmBody => '登出後需要重新登入才能使用 Uwearis。';

  @override
  String get deleteAccount => '刪除帳號';

  @override
  String get tierGold => '金牌';

  @override
  String get tierSilver => '銀牌';

  @override
  String get tierBronze => '銅牌';

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
  String get addVersionButton => '新增版本';

  @override
  String get addVersionTitle => '新增版本';

  @override
  String get versionLimitReachedTitle => '已達版本上限';

  @override
  String get versionLimitReachedBody => '每套穿搭最多可保留 10 個版本，請先刪除一個版本再新增。';

  @override
  String get currentOutfitLabel => '目前穿搭';

  @override
  String get accessoriesLabel => '配件';

  @override
  String get optionalLabel => '選填';

  @override
  String get createOutfit => '建立造型';

  @override
  String get createVersion => '建立版本';

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
  String get outfitItemsLabel => '你的穿搭';

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
  String get finishOutfit => 'AI 造型';

  @override
  String get finishOutfitDescription => '讓 AI 幫你完成穿搭。';

  @override
  String get finishWithAi => '開始';

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
  String get editItinerary => '編輯行程';

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
  String get itineraryAndDatesLabel => '行程與日期';

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
  String get letUwearisPlanOutfitsHint =>
      'Uwearis 會用行李箱裡的衣物搭出幾套穿搭，旅途中依當天心情自由挑選。';

  @override
  String get planTripOutfits => '規劃行程穿搭';

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
  String get addLocation => '新增行程';

  @override
  String get camera => '拍照';

  @override
  String get switchCamera => '切換鏡頭';

  @override
  String get cameraUnavailable => '無法開啟相機';

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
  String get garmentSaveFailed => '無法儲存，請再試一次。';

  @override
  String get garmentDeleteFailed => '無法刪除，請再試一次。';

  @override
  String get unsavedChangesTitle => '你有未儲存的變更';

  @override
  String get unsavedChangesBody => '如果離開此頁面，你的變更將會遺失。';

  @override
  String get autoSaveFailedLeaveBody => '最新的變更未能儲存。如果現在離開，這些變更將會遺失。';

  @override
  String get savingEllipsis => '儲存中…';

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
  String get closetMatch => '衣櫥匹配度';

  @override
  String get viewClosetMatch => '查看衣櫥匹配度';

  @override
  String get viewMatch => '查看匹配度';

  @override
  String get closetAnalysisFailed => '分析失敗，請再試一次。';

  @override
  String get closetAnalysisGarmentNotFound => '在你的衣櫃中找不到這件單品了。';

  @override
  String get versatilityDescription => '這件單品跟你衣櫃的搭配度。';

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
  String outfitIdeaNumber(int number) {
    return '穿搭 $number';
  }

  @override
  String get tryItOn => '試穿看看';

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
  String get fitSkinny => '緊身';

  @override
  String get fitSlim => '修身';

  @override
  String get fitRegular => '標準';

  @override
  String get fitRelaxed => '微寬鬆';

  @override
  String get fitOversized => '寬鬆';

  @override
  String get silhouetteLabel => '形狀';

  @override
  String get sleeveLengthLabel => '袖長';

  @override
  String get cropLengthLabel => '下身長度';

  @override
  String get silhouetteStraight => '直筒';

  @override
  String get silhouetteBoxy => '方正短寬';

  @override
  String get silhouetteLongline => '長版';

  @override
  String get silhouetteCropped => '短版';

  @override
  String get silhouetteCocoon => '繭型';

  @override
  String get silhouetteTapered => '錐形';

  @override
  String get silhouetteBalloon => '氣球褲';

  @override
  String get silhouetteJogger => '束口';

  @override
  String get silhouetteFlared => '喇叭／傘擺';

  @override
  String get silhouettePencil => '窄裙';

  @override
  String get silhouetteALine => 'A 字';

  @override
  String get silhouettePleated => '百褶';

  @override
  String get silhouetteShift => '直身';

  @override
  String get silhouetteFitAndFlare => '收腰傘擺';

  @override
  String get sleeveSleeveless => '無袖';

  @override
  String get sleeveShort => '短袖';

  @override
  String get sleeveThreeQuarter => '五分／七分袖';

  @override
  String get sleeveLong => '長袖';

  @override
  String get cropFullLength => '全長';

  @override
  String get cropNineLength => '九分';

  @override
  String get cropSevenLength => '七分';

  @override
  String get cropFiveLength => '五分';

  @override
  String get cropShorts => '短褲';

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
  String get usedInOutfits => '已用於穿搭';

  @override
  String usedInOutfitsCount(int count) {
    return '$count 套穿搭';
  }

  @override
  String get selectAColor => '選擇顏色';

  @override
  String get chooseColorTitle => '選擇顏色';

  @override
  String get chooseBackgroundTitle => '選擇背景';

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
  String get styleAuto => '自動';

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
  String get updatingTripEllipsis => '更新行程中…';

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
  String get thinkingEllipsis => '思考中…';

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
  String get addFromOutfit => '從已儲存的穿搭新增';

  @override
  String get selectAnOutfitTitle => '選擇穿搭';

  @override
  String get selectVersionTitle => '選擇版本';

  @override
  String get allItemsAlreadyInSuitcase => '此版本的單品都已在行李箱中。';

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
  String suitcaseItemsCount(int count) {
    return '$count 件';
  }

  @override
  String get failedToUpdateSuitcase => '更新行李箱失敗';

  @override
  String get failedToRemoveItem => '移除項目失敗';

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
  String get todaysOutfit => '今日穿搭';

  @override
  String get latestOutfitTitle => '你的最新穿搭';

  @override
  String get loadingWeatherEllipsis => '載入天氣中…';

  @override
  String get viewDetails => '查看詳情';

  @override
  String get viewFullOutfit => '查看完整穿搭';

  @override
  String get gettingStartedSectionLabel => '開始使用';

  @override
  String get gettingStartedWelcomeTitle => '歡迎使用 Uwearis';

  @override
  String get gettingStartedWelcomeSubtitle => '設定你的個人資料並建立衣櫥，解鎖專屬的穿搭預覽。';

  @override
  String get gettingStartedGetStartedButton => '開始設定';

  @override
  String get gettingStartedNextButton => '下一步';

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
  String get loginTagline => '你的每日 AI 穿搭師';

  @override
  String loginTermsNotice(String terms, String privacy) {
    return '繼續即表示你同意我們的$terms與$privacy。';
  }

  @override
  String get termsOfService => '服務條款';

  @override
  String get privacyPolicy => '隱私權政策';

  @override
  String get contactSupport => '聯絡客服';

  @override
  String get helpAndLegal => '說明與法律資訊';

  @override
  String appVersionLabel(String version) {
    return '版本 $version';
  }

  @override
  String get supportEmailSubject => 'Uwearis 客服';

  @override
  String supportEmailBody(String version, String device, String userId) {
    return '請在這行上方描述你遇到的問題。\n\n---\nApp 版本：$version\n裝置：$device\n使用者 ID：$userId';
  }

  @override
  String get openLinkFailed => '無法開啟頁面，請稍後再試。';

  @override
  String supportEmailCopied(String email) {
    return '無法開啟郵件 App。已複製客服信箱 $email，請貼到任何郵件 App 寄信給我們。';
  }

  @override
  String get aiConsentTitle => 'AI 功能的資料使用說明';

  @override
  String aiConsentBody(String provider) {
    return '為了分析衣物、生成試穿圖和規劃穿搭，Uwearis 會把你提供的照片（衣物照、身形與臉部參考照、Match a Look 參考照）以及相關資料（衣物資訊、身高體重、溫度偏好、行程的地點、日期與天氣）傳送給第三方 AI 服務供應商（目前為 $provider）處理。你可以隨時在 App 裡刪除照片或帳號。';
  }

  @override
  String get aiConsentAgree => '同意並繼續';

  @override
  String get aiConsentDecline => '暫不使用';

  @override
  String get continueWithApple => '使用 Apple 繼續';

  @override
  String get signInWithGoogle => '使用 Google 登入';

  @override
  String get signInWithFacebook => '使用 Facebook 登入';

  @override
  String get loginFailed => '登入失敗，請再試一次。';

  @override
  String get copyrightText => '© Uwearis Inc. 版權所有';

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

  @override
  String get homeHeaderDatePattern => 'M月d日 EEEE';

  @override
  String get debugTools => '測試工具';

  @override
  String get debugToolsErrorDialogButton => '顯示後端錯誤彈窗';

  @override
  String get debugToolsErrorDialogSummary => '預覽收到後端錯誤時的彈窗';

  @override
  String get debugToolsSampleErrorMessage => '這是一則模擬的後端錯誤訊息，用於預覽錯誤彈窗的設計。';

  @override
  String get debugToolsComponentGallery => '元件展示';

  @override
  String get debugToolsComponentGallerySummary =>
      '按鈕、卡片、標籤與狀態，含 1.0 / 1.3 / 2.0 文字縮放';

  @override
  String get debugToolsTestDartError => '送出測試錯誤';

  @override
  String get debugToolsTestDartErrorSummary =>
      '拋出未捕捉的 Dart 例外，下次啟動後會出現在 Crashlytics（僅限非 debug build）';

  @override
  String get debugToolsTestNativeCrash => '強制原生閃退';

  @override
  String get debugToolsTestNativeCrashSummary => '立即關閉 App，用來測試閃退符號化';

  @override
  String get createOutfitMissingItemsTitle => '還缺少單品';

  @override
  String get createOutfitMissingItemsBody => '加入以下單品，就能建立造型。';

  @override
  String get createOutfitMinGarmentsBody => '至少選擇 2 件衣物，就能建立造型。';

  @override
  String get createVersionUnchangedTitle => '尚未做任何變更';

  @override
  String get createVersionUnchangedBody => '更換衣物或背景後，才能建立新版本。';

  @override
  String get yourTripOutfits => '你的旅行穿搭';

  @override
  String tripOutfitsSuggestedRange(int min, int max, int days) {
    return '$days 天的行程約需 $min–$max 套';
  }

  @override
  String get findMoreOutfits => 'AI 新增穿搭';

  @override
  String get refreshSuggestions => '更新 AI 推薦';

  @override
  String get refreshSuggestionsTitle => '要更新 AI 推薦嗎？';

  @override
  String refreshSuggestionsBody(int count) {
    return 'Uwearis 會用新的組合取代 $count 套 AI 推薦。已儲存、改過、保留或已試穿的穿搭都不會變動。';
  }

  @override
  String get refresh => '更新';

  @override
  String get noMoreTripOutfitCombinations => '目前的行李箱找不到更多合適的組合了。';

  @override
  String addedTripOutfitsCount(int count) {
    return '新增了 $count 套穿搭。';
  }

  @override
  String savedCandidatesAvailable(int count) {
    return '你有 $count 套穿搭適合這個行李箱，可以在下方加入。';
  }

  @override
  String get fromYourOutfits => '你的穿搭也適合';

  @override
  String get fromYourOutfitsHint => '需要的衣物都已經在行李箱裡。';

  @override
  String get addToTrip => '加入旅行';

  @override
  String get tripOutfitsEmptyHint => '先把衣物或已儲存的穿搭放進行李箱吧。';

  @override
  String get openSuitcase => '打開行李箱';

  @override
  String get tripOutfitSourceSaved => '已儲存';

  @override
  String get tripOutfitSourceSuggested => 'AI 推薦';

  @override
  String get tripOutfitSourceManual => '自訂';

  @override
  String get tripOutfitKept => '已保留';

  @override
  String get keepOutfit => '保留穿搭';

  @override
  String get unkeepOutfit => '取消保留';

  @override
  String get removeFromTrip => '從旅行移除';

  @override
  String get removeTripOutfitTitle => '要從旅行移除嗎？';

  @override
  String get removeTripOutfitBody => '這套穿搭會從這趟旅行移除，行李箱與已儲存的穿搭都不會變動。';

  @override
  String tripOutfitFallbackName(int index) {
    return '穿搭 $index';
  }

  @override
  String missingGarmentsCount(int count) {
    return '缺少 $count 件衣物';
  }

  @override
  String get missingGarmentsDeletedHint => '有衣物已從衣櫃刪除，請編輯這套穿搭來替換。';

  @override
  String get tripOutfitAlreadyAdded => '已經加入這趟旅行';

  @override
  String get tripOutfitDuplicate => '這趟旅行已經有相同衣物的穿搭。';

  @override
  String get tripOutfitIncomplete => '穿搭需要上衣和下身（或連身服裝），加上一雙鞋。';

  @override
  String get tripOutfitGarmentNotPacked => '請選擇行李箱裡的衣物。';

  @override
  String get tripOutfitLimitReached => '這趟旅行的穿搭已達上限。';

  @override
  String get tripOutfitGenerationInProgress => 'Uwearis 正在為這趟旅行搭配穿搭，請稍候。';

  @override
  String get savedOutfitUnavailable => '這套穿搭有衣物已從衣櫃刪除。';

  @override
  String get tripOutfitMissingGarmentsTryOn => '請先把缺少的衣物放回行李箱或編輯穿搭，再進行試穿。';

  @override
  String get failedToAddTripOutfit => '無法加入這套穿搭，請再試一次。';

  @override
  String get failedToRemoveTripOutfit => '無法移除這套穿搭，請再試一次。';

  @override
  String get addedOutfitToTrip => '已加入這趟旅行。';

  @override
  String addedOutfitToTripPacked(int count) {
    return '已加入這趟旅行，並打包了 $count 件衣物。';
  }

  @override
  String savedOutfitsInTripCount(int count) {
    return '已加入 $count 套';
  }

  @override
  String get tripOutfitEdited => '已編輯';

  @override
  String get itineraryTitle => '行程';

  @override
  String tripOutfitsCount(int count) {
    return '穿搭（$count）';
  }

  @override
  String get addTripOutfit => '手動新增';

  @override
  String get refreshAiButton => '更新 AI 穿搭';

  @override
  String tripOutfitsGoodVariety(int days) {
    return '$days 天的穿搭選擇很充足';
  }

  @override
  String get tripOutfitsEmptyTitle => '還沒有旅行穿搭';
}
