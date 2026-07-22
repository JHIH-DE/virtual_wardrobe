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
  String get bodyProfile => '身形檔案';

  @override
  String get styleProfile => '風格檔案';

  @override
  String get dailyPreferences => '每日穿搭偏好';

  @override
  String get logout => '登出';

  @override
  String get findYourStyle => '探索你的風格';

  @override
  String get styleSelectionInstruction => '選擇最多 3 種最符合你日常穿搭的風格。';

  @override
  String get styleSelectionDescription => '我們將根據你的選擇，為你打造個人化的穿搭推薦。';

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
  String get renameLook => '重新命名穿搭';

  @override
  String get lookNameLabel => '這套穿搭的名稱';

  @override
  String get remixLook => '重新混搭';

  @override
  String get saveLook => '儲存穿搭';

  @override
  String get loadingGarments => '載入服飾中…';

  @override
  String get myCollection => '我的收藏';

  @override
  String get myLook => '我的穿搭';

  @override
  String get shareComingSoon => '分享功能即將推出';

  @override
  String get failedToLoadImage => '圖片載入失敗';

  @override
  String get failedToLoadGarments => '服飾載入失敗';

  @override
  String get saveThisLookTitle => '儲存這套穿搭？';

  @override
  String get saveThisLookBody => '要將這套穿搭加入你的收藏嗎？';

  @override
  String get removeLookTitle => '移除穿搭？';

  @override
  String get removeLookBody => '這套穿搭將從你的穿搭列表中移除。';

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
  String get navHome => '首頁';

  @override
  String get navCloset => '衣櫃';

  @override
  String get navLooks => '穿搭';

  @override
  String get navTrips => '行程';

  @override
  String get quickActions => '快速操作';

  @override
  String get quickActionAddClothing => '新增衣物';

  @override
  String get quickActionAddLook => '新增穿搭';

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
  String get editTripName => '編輯行程名稱';

  @override
  String get editDestinations => '編輯目的地';

  @override
  String get enterTripName => '輸入行程名稱';

  @override
  String get editTripPurpose => '編輯行程目的';

  @override
  String get deleteTrip => '刪除行程';

  @override
  String get deleteTripConfirmation => '確定要刪除這個行程嗎？';

  @override
  String get viewPlan => '查看行程';

  @override
  String get tripNameLabel => '行程名稱';

  @override
  String get tripPurposeLabel => '行程目的';

  @override
  String get create => '建立';

  @override
  String get fillAllFieldsError => '請填寫所有欄位';

  @override
  String get regenerate => '重新產生';

  @override
  String get loading => '載入中…';

  @override
  String get tryAgain => '再試一次';

  @override
  String get generatingLookEllipsis => '正在產生你的穿搭…';

  @override
  String get noLookImageYet => '尚無穿搭圖片';

  @override
  String get generateLook => '產生穿搭';

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
  String lookFallbackTitle(int id) {
    return '穿搭 #$id';
  }

  @override
  String get failedToLoad => '載入失敗';

  @override
  String get noImage => '無圖片';

  @override
  String get tripPurposeLeisureTravel => '休閒旅遊';

  @override
  String get tripPurposeBusinessTrip => '商務出差';

  @override
  String get tripPurposeFamilyTrip => '家庭旅遊';

  @override
  String get tripPurposeOutdoorTrip => '戶外旅遊';

  @override
  String get tripPurposeCityTrip => '城市旅遊';

  @override
  String get tripPurposeResortVacation => '度假 / 休憩';

  @override
  String get tripPurposeMixed => '綜合';

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
  String outfitCombosPossible(int combos) {
    return '可組成 $combos 種穿搭';
  }

  @override
  String get addMorePiecesHint => '再新增幾件單品即可解鎖穿搭建議';

  @override
  String outfitComboBasis(int tops, int bottoms, int shoes) {
    return '根據你衣櫃中已有的 $tops 件上衣、$bottoms 件下身和 $shoes 雙鞋子——這件單品很有機會派上用場。';
  }

  @override
  String get clothingNameLabel => '衣物名稱';

  @override
  String get nameTheClothingHint => '為這件衣物命名';

  @override
  String get pleaseEnterNameError => '請輸入名稱';

  @override
  String get clothingCategoryLabel => '衣物類別';

  @override
  String get productType => '商品類型';

  @override
  String get productTypeHint => '例如：上衣';

  @override
  String get pleaseEnterProductTypeError => '請輸入商品類型';

  @override
  String get color => '顏色';

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
  String get notUsedInLooksYet => '尚未用於任何穿搭';

  @override
  String get usedInLooks => '已用於穿搭';

  @override
  String get selectAColor => '選擇顏色';

  @override
  String get chooseColorTitle => '選擇顏色';

  @override
  String get clear => '清除';

  @override
  String get selectDate => '選擇日期';

  @override
  String get editImage => '編輯圖片';

  @override
  String get changesSaved => '變更已儲存';

  @override
  String get midLayer => '中層';

  @override
  String get outerwear => '外套';

  @override
  String get createLook => '建立穿搭';

  @override
  String get selectCombinationsInstruction => '選擇你想嘗試的衣物組合，然後點選「建立穿搭」查看試穿結果！';

  @override
  String get creatingLooksEllipsis => '建立穿搭中…';

  @override
  String get loadingClosetEllipsis => '載入衣櫃中…';

  @override
  String get personalDetailsTitle => '個人資料';

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
  String get noLooksYet => '尚無穿搭。';

  @override
  String get itemNotUsedInLooksYet => '這件單品尚未用於任何穿搭。';

  @override
  String get failedToUpdateFavorite => '更新收藏失敗';

  @override
  String get creatingTripEllipsis => '建立行程中…';

  @override
  String get failedToCreateTrip => '建立行程失敗';

  @override
  String get tripPlannerTitle => '行程規劃';

  @override
  String get loadingTripEllipsis => '載入行程中…';

  @override
  String get noTripsPlannedYet => '尚無規劃中的行程';

  @override
  String get statusOngoing => '進行中';

  @override
  String get statusUpcoming => '即將到來';

  @override
  String get statusPast => '已結束';

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
  String wardrobeForDate(String date) {
    return '$date 的服裝';
  }

  @override
  String get noItemsPlanned => '尚無規劃項目';

  @override
  String get thinkingEllipsis => '思考中…';

  @override
  String get suitcaseLabel => '行李箱';

  @override
  String get packClothingHint => '為這趟行程打包衣物';

  @override
  String get savedToCloset => '已儲存至衣櫃 ✅';

  @override
  String get selectGarmentsTitle => '選擇衣物';

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
  String get occasionDaily => '🏠 日常';

  @override
  String get occasionWork => '💼 工作';

  @override
  String get occasionDate => '❤️ 約會';

  @override
  String get occasionSport => '🏃 運動';

  @override
  String get occasionFormal => '👔 正式';

  @override
  String get settingsSaved => '設定已儲存';

  @override
  String get comfortAdjustment => '舒適度調整';

  @override
  String get dailyOccasions => '每日場合';

  @override
  String dayWithTodaySuffix(String day) {
    return '$day（今天）';
  }

  @override
  String get apply => '套用';

  @override
  String get perceivedTempOffset => '體感溫度調整';

  @override
  String get todaysLook => '今日穿搭';

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
  String get fullBodyPhotoLabel => '全身照';

  @override
  String get figureDetailLabel => '身形細節';

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
  String get bodyProfile => '身形檔案';

  @override
  String get styleProfile => '風格檔案';

  @override
  String get dailyPreferences => '每日穿搭偏好';

  @override
  String get logout => '登出';

  @override
  String get findYourStyle => '探索你的風格';

  @override
  String get styleSelectionInstruction => '選擇最多 3 種最符合你日常穿搭的風格。';

  @override
  String get styleSelectionDescription => '我們將根據你的選擇，為你打造個人化的穿搭推薦。';

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
  String get renameLook => '重新命名穿搭';

  @override
  String get lookNameLabel => '這套穿搭的名稱';

  @override
  String get remixLook => '重新混搭';

  @override
  String get saveLook => '儲存穿搭';

  @override
  String get loadingGarments => '載入服飾中…';

  @override
  String get myCollection => '我的收藏';

  @override
  String get myLook => '我的穿搭';

  @override
  String get shareComingSoon => '分享功能即將推出';

  @override
  String get failedToLoadImage => '圖片載入失敗';

  @override
  String get failedToLoadGarments => '服飾載入失敗';

  @override
  String get saveThisLookTitle => '儲存這套穿搭？';

  @override
  String get saveThisLookBody => '要將這套穿搭加入你的收藏嗎？';

  @override
  String get removeLookTitle => '移除穿搭？';

  @override
  String get removeLookBody => '這套穿搭將從你的穿搭列表中移除。';

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
  String get navHome => '首頁';

  @override
  String get navCloset => '衣櫃';

  @override
  String get navLooks => '穿搭';

  @override
  String get navTrips => '行程';

  @override
  String get quickActions => '快速操作';

  @override
  String get quickActionAddClothing => '新增衣物';

  @override
  String get quickActionAddLook => '新增穿搭';

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
  String get editTripName => '編輯行程名稱';

  @override
  String get editDestinations => '編輯目的地';

  @override
  String get enterTripName => '輸入行程名稱';

  @override
  String get editTripPurpose => '編輯行程目的';

  @override
  String get deleteTrip => '刪除行程';

  @override
  String get deleteTripConfirmation => '確定要刪除這個行程嗎？';

  @override
  String get viewPlan => '查看行程';

  @override
  String get tripNameLabel => '行程名稱';

  @override
  String get tripPurposeLabel => '行程目的';

  @override
  String get create => '建立';

  @override
  String get fillAllFieldsError => '請填寫所有欄位';

  @override
  String get regenerate => '重新產生';

  @override
  String get loading => '載入中…';

  @override
  String get tryAgain => '再試一次';

  @override
  String get generatingLookEllipsis => '正在產生你的穿搭…';

  @override
  String get noLookImageYet => '尚無穿搭圖片';

  @override
  String get generateLook => '產生穿搭';

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
  String lookFallbackTitle(int id) {
    return '穿搭 #$id';
  }

  @override
  String get failedToLoad => '載入失敗';

  @override
  String get noImage => '無圖片';

  @override
  String get tripPurposeLeisureTravel => '休閒旅遊';

  @override
  String get tripPurposeBusinessTrip => '商務出差';

  @override
  String get tripPurposeFamilyTrip => '家庭旅遊';

  @override
  String get tripPurposeOutdoorTrip => '戶外旅遊';

  @override
  String get tripPurposeCityTrip => '城市旅遊';

  @override
  String get tripPurposeResortVacation => '度假 / 休憩';

  @override
  String get tripPurposeMixed => '綜合';

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
  String outfitCombosPossible(int combos) {
    return '可組成 $combos 種穿搭';
  }

  @override
  String get addMorePiecesHint => '再新增幾件單品即可解鎖穿搭建議';

  @override
  String outfitComboBasis(int tops, int bottoms, int shoes) {
    return '根據你衣櫃中已有的 $tops 件上衣、$bottoms 件下身和 $shoes 雙鞋子——這件單品很有機會派上用場。';
  }

  @override
  String get clothingNameLabel => '衣物名稱';

  @override
  String get nameTheClothingHint => '為這件衣物命名';

  @override
  String get pleaseEnterNameError => '請輸入名稱';

  @override
  String get clothingCategoryLabel => '衣物類別';

  @override
  String get productType => '商品類型';

  @override
  String get productTypeHint => '例如：上衣';

  @override
  String get pleaseEnterProductTypeError => '請輸入商品類型';

  @override
  String get color => '顏色';

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
  String get notUsedInLooksYet => '尚未用於任何穿搭';

  @override
  String get usedInLooks => '已用於穿搭';

  @override
  String get selectAColor => '選擇顏色';

  @override
  String get chooseColorTitle => '選擇顏色';

  @override
  String get clear => '清除';

  @override
  String get selectDate => '選擇日期';

  @override
  String get editImage => '編輯圖片';

  @override
  String get changesSaved => '變更已儲存';

  @override
  String get midLayer => '中層';

  @override
  String get outerwear => '外套';

  @override
  String get createLook => '建立穿搭';

  @override
  String get selectCombinationsInstruction => '選擇你想嘗試的衣物組合，然後點選「建立穿搭」查看試穿結果！';

  @override
  String get creatingLooksEllipsis => '建立穿搭中…';

  @override
  String get loadingClosetEllipsis => '載入衣櫃中…';

  @override
  String get personalDetailsTitle => '個人資料';

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
  String get noLooksYet => '尚無穿搭。';

  @override
  String get itemNotUsedInLooksYet => '這件單品尚未用於任何穿搭。';

  @override
  String get failedToUpdateFavorite => '更新收藏失敗';

  @override
  String get creatingTripEllipsis => '建立行程中…';

  @override
  String get failedToCreateTrip => '建立行程失敗';

  @override
  String get tripPlannerTitle => '行程規劃';

  @override
  String get loadingTripEllipsis => '載入行程中…';

  @override
  String get noTripsPlannedYet => '尚無規劃中的行程';

  @override
  String get statusOngoing => '進行中';

  @override
  String get statusUpcoming => '即將到來';

  @override
  String get statusPast => '已結束';

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
  String wardrobeForDate(String date) {
    return '$date 的服裝';
  }

  @override
  String get noItemsPlanned => '尚無規劃項目';

  @override
  String get thinkingEllipsis => '思考中…';

  @override
  String get suitcaseLabel => '行李箱';

  @override
  String get packClothingHint => '為這趟行程打包衣物';

  @override
  String get savedToCloset => '已儲存至衣櫃 ✅';

  @override
  String get selectGarmentsTitle => '選擇衣物';

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
  String get occasionDaily => '🏠 日常';

  @override
  String get occasionWork => '💼 工作';

  @override
  String get occasionDate => '❤️ 約會';

  @override
  String get occasionSport => '🏃 運動';

  @override
  String get occasionFormal => '👔 正式';

  @override
  String get settingsSaved => '設定已儲存';

  @override
  String get comfortAdjustment => '舒適度調整';

  @override
  String get dailyOccasions => '每日場合';

  @override
  String dayWithTodaySuffix(String day) {
    return '$day（今天）';
  }

  @override
  String get apply => '套用';

  @override
  String get perceivedTempOffset => '體感溫度調整';

  @override
  String get todaysLook => '今日穿搭';

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
  String get fullBodyPhotoLabel => '全身照';

  @override
  String get figureDetailLabel => '身形細節';

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
