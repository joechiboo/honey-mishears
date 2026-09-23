# Google Play 上架

照順序做。工具鏈那關已經過了，剩下的三個 🟡 都得你本人動手。

---

## 0. 現況盤點（2026-09-22，升級後）

| 項目 | 現在 | 狀態 |
|---|---|---|
| Flutter | **3.47.5** | ✅ 已升（原 3.19.6） |
| targetSdk / compileSdk | `flutter.targetSdkVersion`（= 36） | ✅ 交給 Flutter 決定，不寫死 |
| 16 KB page size | 新引擎已支援 | ✅ 隨升級解決 |
| AGP / Gradle / Kotlin | **9.1.0 / 9.3.1 / 2.4.0** | ✅ 對齊 3.47.5 樣板 |
| JDK | 17 | ✅ AGP 9 要求 |
| minSdk | **24**（原 21） | ⚠️ 支援下限從 Android 5.0 提到 7.0 |
| applicationId | `com.joechiboo.honey_mishears` | ✅ |
| 版本號 | `1.0.0+1` | ✅ |
| App 名稱 | AI 老婆 | ✅ |
| 圖示（含 adaptive / themed） | 有 | ✅ |
| INTERNET 權限 | main manifest 有 | ✅ |
| 上傳金鑰 | **沒有**，要自己生 | 🟡 你要動手 |
| 隱私政策 | 草稿有，缺公開網址 | 🟡 你要動手 |
| 商店截圖 | 沒有，至少要 2 張 | 🟡 你要動手 |

---

## 1. ✅ 工具鏈升級（已完成 2026-09-22）

**2026-08-31 起，新上架與更新都必須 target Android 16（API 36）。**
另外 target 35 以上的 App 必須支援 **16 KB memory page size**，
Play 從 2027-02-01 開始硬性擋更新。

這兩件都不是改個數字能解決的：

- compileSdk 36 需要 AGP 8.9+，AGP 8.x 需要 Gradle 8.x 與 JDK 17
- 16 KB 對齊要靠 **Flutter 引擎本身**重新編譯過的 .so，
  3.19.6 的引擎沒有，改 gradle 設定救不回來

所以路徑只有一條：**先把 Flutter 升到現行 stable（3.47.5），
再讓它重建 android 設定**。

> **實際做完的結果**：Dart 程式碼一行都沒改就編得過——
> 50 個 analyze 提示全是 `withOpacity` 棄用，都是 info 不是 error。
> 真正要動的只有 `android/`：AGP 7.3→9.1、Gradle 7.6.3→9.3.1、
> Kotlin 1.7.10→2.4.0、Java 1.8→17，以及把寫死的 `compileSdk 34`
> 換成 `flutter.compileSdkVersion`（下次 Play 再推規則就不用手改）。
>
> ⚠️ `minSdk` 跟著變成 `flutter.minSdkVersion`（= **24**），
> 支援下限從 Android 5.0 提到 7.0。要保留 21 的話改回寫死，
> 但新版外掛不一定還支援得了。
>
> **2026-09-23 補：release build 驗過了**，但中間又撞了三個坑，都不是 Dart：
> 1. `speech_to_text` 6.x 在 AGP 9 configure 時 NPE → 升 7.5（錯誤畫面附的
>    「改 `android.newDsl`」提示是誤導，那行早就有）
> 2. `permission_handler_android` 14.x 寫死 `compileSdk = 37`，而且 AAR metadata
>    要求 app 也 ≥ 37；Android 17 平台在 SDK 裡叫 `android-37.0` →
>    app 寫 `compileSdk = 37` + `compileSdkMinor = 0`，外掛由 root build.gradle 的 hook 補
> 3. Kotlin 2.4 增量快取在 Windows 上關不掉（`Could not close incremental caches`）→
>    `gradle.properties` 關掉 `kotlin.incremental`
>
> fat APK 72MB 是正常的（.so 不壓縮＋三個 ABI），Play 走 AAB 會拆。

### 升級要注意

`flutter upgrade` 是**改整台機器的 SDK**，會影響這台電腦上其他 Flutter 專案。
若有其他專案在跑，改用 [fvm](https://fvm.app/) 只針對本專案鎖版本。

跨兩年半（3.19 → 3.47）預期會壞的地方：

| 東西 | 風險 |
|---|---|
| `Color.withOpacity()` | 已棄用，改 `withValues(alpha:)`。本專案用了**很多**（兩支 painter、telemetry_sheet） |
| `rive: ^0.13.20` | 要大版升，Rive 的 runtime API 改過。目前沒有 .riv 素材，只要能編譯就好 |
| `speech_to_text: ^6.6.2` | 要升 7.x，`initialize`/`listen` 的參數有調整——**這是 App 的核心，升完一定要實機重測** |
| `permission_handler: ^11.3.1` | 升 12.x |
| `flutter_lints: ^3.0.0` | 升 6.x，可能冒出一批新 lint |
| android/ 樣板 | 建議讓 `flutter create --platforms=android .` 重生一份再把客製的部分搬回去（見下） |

### android/ 有哪些客製，重生樣板時不能丟

- `AndroidManifest.xml`：RECORD_AUDIO、INTERNET、`<queries>` 裡的
  `RecognitionService`（**少了它 speech_to_text 的 initialize() 直接回 false**）
- `build.gradle`：`hasReleaseKeystore ? release : debug` 的簽章三元判斷
- `res/values/colors.xml`、`styles.xml`、`launch_background.xml`：啟動底色
- `mipmap-*`：圖示全套（也可以用 `tool/generate_app_icon.py` 重生）
- `kotlin/.../SpeechModelBridge.kt`：語言包 API 的 platform channel

### 升完的驗收

```bash
flutter analyze                 # 要乾淨
flutter test                    # 80 個測試要全過
flutter build apk --release     # 要能過
flutter install --release -d <serial>
```
然後**實機測語音**——這是模擬器測不到、升級最容易壞的部分。

---

## 2. 🟡 上傳金鑰

我不幫你生：這會產生一把私鑰與密碼，那東西不該經過我。

```bash
keytool -genkey -v -keystore %USERPROFILE%\honey-mishears-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

然後建 `android/key.properties`（已在 .gitignore，不進版控）：

```properties
storePassword=你的密碼
keyPassword=你的密碼
keyAlias=upload
storeFile=C:/Users/你的帳號/honey-mishears-upload.jks
```

⚠️ **這把 .jks 弄丟就永遠無法更新這個 App**（除非申請 Play App Signing 重設）。
備份到密碼管理員或離線硬碟，不要只留在這台電腦。

---

## 3. 🟡 隱私政策要有網址

草稿在 [`privacy-policy.md`](privacy-policy.md)，裡面有兩個 `<...>` 要先填。
Play Console 需要一個**公開可存取的網址**，最省事的兩條路：

**GitHub Pages（推薦，免費）**
1. repo → Settings → Pages → Source 選 `main` 分支 `/docs` 資料夾
2. 網址會是 `https://joechiboo.github.io/honey-mishears/privacy-policy`

**或**放到你現有的 Plesk 站台（見全域 runbook `plesk-static-site-deploy`）。

---

## 4. 商店資料

### 應用程式名稱（30 字內）
```
AI 老婆
```

### 簡短說明（80 字內）
```
會裝傻的語音互動老婆。說「親一個」，她開始打掃房間。
```

### 完整說明（4000 字內）
```
一個語音互動的 2D 角色 App。你按住按鈕對她說話，她永遠聽錯——
而且錯得一本正經、理所當然。

你說「親一個」，她聽成「清一個」，捲起袖子開始打掃房間。
你說「抱一個」，她聽成「報一個」，戴上墨鏡開始報明牌。
你說「你好」，她聽成「泥好」，去敷了一片面膜。
你說「抱緊我」，她聽成「包緊我」，換上厚外套圍上圍巾包成一團。
聽不懂的時候，她會歪頭裝傻，說一句可愛的困惑台詞。

每個情境都有多句台詞隨機挑選，避免重複感。

【關於運作方式】
・回應邏輯完全離線，不使用任何語言模型，純粹做關鍵字比對
・語音轉文字交由你裝置上的系統辨識服務處理
・App 會回傳辨識完的文字（不含錄音）以持續增加新的梗，可於設定中關閉

【娛樂性質聲明】
App 中的「明牌」號碼為電腦隨機產生，不具任何預測性，
與真實彩券開獎無關，且不涉及任何真實金錢。
```

### 截圖（至少 2 張，建議 4～6 張）
手機截圖規格：9:16 或 16:9，短邊 ≥ 320px、長邊 ≤ 3840px。

要拍的畫面：待機、打掃（含灰塵）、報明牌（含號碼卡）、敷面膜、包緊、裝傻。
**每張都要先對她說對應的話**，所以這步只能你自己拍——
螢幕鎖著時 `adb exec-out screencap` 只會拍到黑畫面。

解鎖後可以用：
```bash
adb -s <serial> exec-out screencap -p > shot.png
```

### 主要圖片（Feature graphic，1024 × 500）
還沒有。可以用 `tool/render_character_preview.dart` 產出的
`stage_clean.png` 當素材，配上 App 名稱與那句「說『親一個』，她開始打掃房間」。

---

## 5. 資料安全性表單

⚠️ 有了逐字稿回傳之後，**不能再宣告「不蒐集任何資料」**。

| 項目 | 填法 |
|---|---|
| 錄音 | **不蒐集**。音檔沒有離開裝置，只交給系統辨識服務 |
| 應用程式活動 → 其他使用者產生的內容 | **蒐集、且傳輸至第三方** |
| └ 用途 | 應用程式功能、分析 |
| └ 是否必要 | **選用**（使用者可在設定關閉） |
| └ 加密傳輸 | 是（HTTPS） |
| └ 可要求刪除 | 是（提供聯絡信箱） |
| 裝置或其他 ID | **不蒐集**（那組 UUID 是 App 自己產生的，非裝置識別碼） |
| 位置、個人資訊、財務、聯絡人、照片 | 一律不蒐集 |

欄位與程式的對應關係見 [`telemetry.md`](telemetry.md)。

---

## 6. 內容分級問卷

明牌畫面屬**模擬博弈相關的娛樂內容**，務必如實填寫
「不涉及真實金錢、不提供任何獎勵」。

App 內已有娛樂性質聲明（`lib/ui/widgets/lottery_card.dart`），
**那是上架合規所需，請勿移除**。

---

## 7. 打包上傳

```bash
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi... \
  --dart-define=APP_VERSION=1.0.0
# 產物：build/app/outputs/bundle/release/app-release.aab
```

⚠️ 沒帶 `--dart-define` 的話**逐字稿回傳是關閉狀態**——
上架版忘記帶，就等於這個功能沒上。

上傳前先確認工作區乾淨（`git status`），不要把別人未完成的功能一起包進去。

先走 **內部測試（Internal testing）** 軌道給自己與朋友裝，
確認語音辨識、回傳、各情境都正常，再推正式版。
