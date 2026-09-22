# honey-mishears 🎤💕

> A voice-driven 2D companion app where she always "mishears" you — ask for a kiss, get a cleaned room. Built with Flutter & Rive.
>
> 會裝傻的 2D 語音互動老婆。說「親一個」，她開始打掃房間；說「抱一個」，她開始報明牌。Flutter + Rive 打造。

App 名稱：**AI 老婆**

---

## 這是什麼

一個語音互動的 2D 角色 App。你按住按鈕對她說話，她**永遠聽錯**——
而且錯得一本正經、理所當然。

| 你說 | 她聽成 | 她做什麼 |
|------|--------|----------|
| 親一個 | 清一個 | 捲起袖子開始打掃，畫面飄起灰塵 |
| 抱一個 | 報一個 | 戴上墨鏡開始報明牌 |
| 你好 | 泥好 | 敷起白色片狀面膜，閉眼放鬆 |
| 抱緊我 | 包緊我 | 換上厚外套、圍上圍巾，包到只剩眼睛 |
| 其他 | — | 歪頭，說一句可愛的困惑台詞 |

每個情境都有 3 句台詞隨機挑選，避免重複感。

**回應邏輯完全離線、不使用任何語言模型**：語音轉文字後純粹做關鍵字字串比對。
（語音轉文字本身依賴系統的辨識服務與語言包，見下方〈語音辨識〉。）

> ⚠️ 但 App **不是什麼都不出去**：辨識完的文字會回傳，用來找出她聽不懂的話。
> 沒有錄音、沒有她的名字，預設開啟且隨時可關。收什麼、怎麼關、Play 表單怎麼填，
> 見 [`docs/telemetry.md`](docs/telemetry.md)。

---

## 技術規格

| 項目 | 選擇 |
|---|---|
| 框架 | Flutter 3.19（Android 優先） |
| 角色動畫 | Rive 狀態機（素材未完成時走純 Flutter 佔位角色） |
| 語音辨識 | `speech_to_text`，按住說話（系統辨識服務 + 語言包） |
| 語言包 | 自訂 platform channel，App 內引導下載 |
| 權限 | `permission_handler` |
| 回應邏輯 | 語音轉文字 → 關鍵字比對 → 觸發動畫與台詞 |

---

## 專案結構

```
honey-mishears/
├── assets/
│   ├── config/
│   │   └── mishear_rules.json   ← 諧音梗設定檔（新增梗只改這裡）
│   ├── character/default/       ← AI 角色圖放這裡（一個姿勢一張去背 PNG）
│   └── rive/
│       └── (wife.riv)           ← Rive 素材放這裡，目前還沒有
├── docs/
│   └── rive_state_machine.md    ← 給美術的狀態機規格
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── app_config.dart      全域常數（語系、收音秒數、離線開關）
│   │   ├── app_theme.dart       配色
│   │   └── character_pose.dart  角色姿勢 enum ↔ Rive trigger 名稱
│   ├── data/
│   │   ├── telemetry_store.dart     回傳的同意設定與待送佇列
│   │   ├── transcript_record.dart   一筆回傳紀錄（刻意不含什麼，看它的註解）
│   │   ├── mishear_rule.dart        設定檔的資料模型
│   │   └── mishear_repository.dart  讀 JSON
│   ├── services/
│   │   ├── speech_service.dart      語音辨識 + 麥克風權限
│   │   ├── speech_model_service.dart 語言包查詢／下載（接 platform channel）
│   │   ├── mishear_engine.dart      關鍵字比對引擎
│   │   └── lottery_generator.dart   隨機號碼
│   └── ui/
│       ├── home_page.dart           主畫面（流程調度都在這）
│       └── widgets/
│           ├── character_stage.dart       舞台：角色 + 特效
│           ├── character_renderer.dart    決定誰來畫（Rive > 圖片 > 佔位）
│           ├── character_motion.dart      呼吸與歪頭（圖片／佔位角色共用）
│           ├── rive_character.dart        Rive 角色
│           ├── image_character.dart       圖片角色（AI 生成的 PNG）
│           ├── placeholder_character.dart 佔位角色（向量繪製，永遠的保底）
│           ├── painters/
│           │   └── wife_painter.dart     角色的向量筆觸（Path + 漸層）
│           ├── dialogue_bubble.dart       台詞對話框
│           ├── push_to_talk_button.dart   按住說話按鈕
│           ├── dust_effect.dart           灰塵特效
│           ├── lottery_card.dart          明牌號碼卡（含娛樂性質聲明）
│           ├── notice_sheet.dart          權限／錯誤提示面板
│           └── language_pack_sheet.dart   語言包下載引導（五個狀態）
├── tool/
│   ├── generate_app_icon.py           產生 App 圖示
│   └── render_character_preview.dart  把六個姿勢畫成 PNG（調角色時用）
└── android/
    └── app/src/main/kotlin/.../SpeechModelBridge.kt
                                     語言包 API 的 platform channel
                                     （speech_to_text 沒有包這組 API）
```

---

## 怎麼跑

```bash
flutter pub get
flutter devices          # 確認手機有連上（要開 USB 偵錯）
flutter run              # 裝到手機上
```

> ⚠️ **模擬器測不了**：Android 模擬器沒有真的麥克風，語音辨識會失敗。
> 一定要用實體手機測。

裝 APK 給別人試：

```bash
flutter build apk --release
# 產物：build/app/outputs/flutter-apk/app-release.apk
```

---

## 新增一個諧音梗

只要改 [`assets/config/mishear_rules.json`](assets/config/mishear_rules.json)，
**不需要動任何程式碼**：

```json
{
  "id": "cook",
  "label": "煮飯",
  "keywords": ["愛我", "愛你"],
  "mishearAs": "煮我",
  "animationTrigger": "cook",
  "effect": "none",
  "lines": ["煮我？我又不好吃。", "…你是不是餓了？", "煮是可以煮啦，但我建議吃別的。"]
}
```

| 欄位 | 說明 |
|---|---|
| `keywords` | 辨識結果只要「包含」任一個就命中；比對前會去掉標點與空白 |
| `mishearAs` | 顯示在對話框上方的「她聽成 ○○○」 |
| `animationTrigger` | 對應 Rive 狀態機的 trigger 名稱 |
| `effect` | `none` / `dust` / `lottery`（要新的特效才需要寫程式） |
| `lines` | 台詞池，每次隨機挑一句 |

規則依陣列順序比對，**先命中者優先**。

---

## 語音辨識

**分兩層看**：

- **回應邏輯**完全離線：純字串比對，沒有模型、沒有 API 呼叫
- **語音轉文字**交給 Android 系統的辨識服務，需要對應的**語言包**
- **辨識完的文字會回傳**（預設開、可關）：只有文字，沒有音檔。
  這是唯一會主動連外的地方，見 [`docs/telemetry.md`](docs/telemetry.md)

實測 Galaxy S23（API 36）：出廠狀態 `installed: []`，**一個離線語言包都沒有**，
而且 `online: []`——這台機器沒有「連網就能辨識」的退路。所以第一次使用一定會失敗，
必須先下載語言包。

App 因此內建了**語言包下載引導**：偵測到 `error_language_unavailable` 時會自動
彈出面板，Android 13+ 可以直接在 App 內按一鍵下載（`triggerModelDownload`），
不必叫使用者自己去翻系統設定。

> ⚠️ **接手前必讀**：[`docs/speech_recognition.md`](docs/speech_recognition.md)
>
> 這條線有四個坑，而且**每一個的錯誤訊息都指向錯誤的方向**。最容易中的是：
> 裝置把台灣中文叫 `cmn-Hant-TW`，不叫 `zh-TW`；送錯寫法它會**安靜地**退回
> en-US，然後報一個看起來像「中文沒裝好」的錯。

### 除錯

App 右上角 **❓ → 語音診斷** 會顯示引擎狀態、實際送出的語系、可用語系與最後錯誤碼。

```bash
adb logcat -c    # 測之前清空
adb logcat -d | grep -aE "Soda|\[STT\]|\[LangPack\]"
```

辨識器卡在 `error_busy` 且重開 App 無效時（獨占資源沒放乾淨）：

```bash
adb shell am force-stop com.google.android.as
```

---

## 上架 Google Play

1. **產生上傳金鑰**

   ```bash
   keytool -genkey -v -keystore %USERPROFILE%\honey-mishears-upload.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. **建立 `android/key.properties`**（此檔已在 `.gitignore`，不會進版控）

   ```properties
   storePassword=你的密碼
   keyPassword=你的密碼
   keyAlias=upload
   storeFile=C:/Users/你的帳號/honey-mishears-upload.jks
   ```

3. **打包 AAB**

   ```bash
   flutter build appbundle --release \
     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi... \
     --dart-define=APP_VERSION=1.0.0
   # 產物：build/app/outputs/bundle/release/app-release.aab
   ```

   金鑰走 `--dart-define` 而不是寫進檔案，因為這個 repo 是公開的。
   **沒帶就不會回傳任何東西**，這是刻意的預設。

4. **Play Console 需要準備的資料**
   - 資料安全性表單有兩塊要分開填：
     - **錄音**：用途為應用程式功能，且註明*不上傳、不儲存*
       （音檔確實沒有離開裝置，只交給系統辨識服務轉文字）
     - **使用者產生的內容**：**有蒐集**——辨識完的逐字稿會回傳。
       選用（可關）、加密傳輸、傳給第三方（Supabase）。
       逐欄怎麼填見 [`docs/telemetry.md`](docs/telemetry.md) 第五節
   - **隱私政策**：有了逐字稿回傳之後這是必填欄位，不再是選配
   - 內容分級問卷：明牌畫面屬**模擬博弈相關的娛樂內容**，
     務必如實填寫「不涉及真實金錢」
   - 明牌畫面已內建聲明：「僅供娛樂，號碼為電腦隨機產生，不具任何預測性，
     與真實彩券開獎無關。」此聲明為上架合規所需，請勿移除
     （見 `lib/ui/widgets/lottery_card.dart`）

已設定好：`compileSdk 34` / `targetSdk 34`（Play 現行要求）、`minSdk 21`、
release 走 R8 壓縮。

---

## Status

🚧 MVP。角色目前是佔位圖形，Rive 素材規格見
[`docs/rive_state_machine.md`](docs/rive_state_machine.md)。

換成 AI 生成角色圖的路線已經鋪好——把去背 PNG 丟進
[`assets/character/default/`](assets/character/default/README.md) 就會自動生效，
缺圖的姿勢退回 `idle.png`，一張都沒有就退回佔位角色。

形象與未來捏人系統的完整取捨見
[`docs/character_art_roadmap.md`](docs/character_art_roadmap.md)。
