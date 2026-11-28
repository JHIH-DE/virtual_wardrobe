# Uwearis 雜誌後台（CMS）

編輯 App「Explore」雜誌內容的網頁後台（Flutter Web）。文章預覽直接用 App 的排版元件
（`../Uwearis` 的 `lib/features/widgets/magazine/`），預覽看到的就是 App 上的樣子。

## 啟動（本機）

1. 啟動後端（`~/Documents/virtual-wardrobe-backend`）：
   ```bash
   .venv/bin/uvicorn app.main:app --reload --port 8000
   ```
2. 第一次使用：複製設定檔，填入 Google Web OAuth client id（跟 App 的 `GOOGLE_CLIENT_ID` 同一組）：
   ```bash
   cp dart_defines/dev.json.template dart_defines/dev.json
   ```
3. 啟動 CMS（port 必須是 5000，Google 登入和後端 CORS 只允許這個網址）：
   ```bash
   flutter run -d chrome --web-port 5000 --dart-define-from-file=dart_defines/dev.json
   ```
4. 用管理員的 Google 帳號登入（後端 `users.is_admin = 1`）。

## 需要的設定

| 設定 | 位置 |
|---|---|
| Google OAuth「已授權的 JavaScript 來源」加 CMS 網址 | Google Cloud Console（專案 synthetic-arc-482116-f5） |
| 後端 `CORS_ALLOWED_ORIGINS` 加 CMS 網址 | 後端環境變數（預設只有 `http://localhost:5000`） |
| GCS bucket CORS 允許 CMS 網址 GET/PUT | `gcloud storage buckets update gs://virtual-wardrobe-assets --cors-file=...` |
| 管理員帳號 | `UPDATE users SET is_admin = 1 WHERE email = '...'` |

部署到正式網址時，上面三個 CORS / 來源設定都要加上新網址。

## 結構

- `lib/api/`：`ApiClient`（token 只存在記憶體，重新整理頁面要重新登入）、`CmsApi`（對應後端 `docs/magazine_cms.md`）
- `lib/models/`：管理端資料、`StoryDraft`（編輯中的文章與轉成 App 預覽的邏輯）、`story_pages.dart`（Story 的八種版型頁面；欄位上限對應後端 `schemas/magazine.py`）、`media_asset.dart`（圖片出處與使用權）
- `lib/pages/`：登入、期數、文章編輯（文章或 Story 兩種形式，含即時預覽；`story_page_fields.dart` 是各版型的欄位）、單品、使用者（列表與詳情：個人資料、手動加扣點、Uwearis Plus 訂閱、管理員權限；對應後端 `docs/requirements/cms_user_management.md`）
- `lib/utils/image_downscale*.dart`：上傳前把長邊超過 2400px 的圖縮小（瀏覽器 canvas；PNG 維持 PNG 以保留去背透明）
- 圖片欄位下方的「使用權」顯示該圖的授權狀態，點開登記；讀者會看到的圖都要確認使用權才能發佈
- 測試：`flutter test`
