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
| 你好 | 泥好 | 敷起泥膜，眼睛壓兩片小黃瓜 |
| 其他 | — | 歪頭，說一句可愛的困惑台詞 |

每個情境都有 3 句台詞隨機挑選，避免重複感。

**完全離線、不使用任何語言模型**：語音轉文字後純粹做關鍵字字串比對。

---

## 技術規格

| 項目 | 選擇 |
|---|---|
| 框架 | Flutter 3.19（Android 優先） |
| 角色動畫 | Rive 狀態機（素材未完成時走純 Flutter 佔位角色） |
| 語音辨識 | `speech_to_text`，按住說話 |
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
│   │   ├── mishear_rule.dart        設定檔的資料模型
│   │   └── mishear_repository.dart  讀 JSON
│   ├── services/
│   │   ├── speech_service.dart      語音辨識 + 麥克風權限
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
│           ├── placeholder_character.dart 佔位角色（純 Flutter 繪製）
│           ├── dialogue_bubble.dart       台詞對話框
│           ├── push_to_talk_button.dart   按住說話按鈕
│           ├── dust_effect.dart           灰塵特效
│           ├── lottery_card.dart          明牌號碼卡（含娛樂性質聲明）
│           └── notice_sheet.dart          權限／錯誤提示面板
└── android/
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

## 語音辨識是不是真的離線？

分兩層看：

- **回應邏輯**完全離線：純字串比對，沒有任何模型、沒有任何 API 呼叫。
- **語音轉文字**預設交給 Android 系統服務決定，多數手機會走 Google 的線上辨識。

要強制完全不連網，把 `lib/core/app_config.dart` 的
`forceOnDeviceRecognition` 改成 `true`——但使用者必須先在
**設定 → 系統 → 語言與輸入 → 語音辨識** 下載中文離線語音包，
否則辨識會直接失敗。MVP 階段先維持 `false` 確保流程跑得通。

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
   flutter build appbundle --release
   # 產物：build/app/outputs/bundle/release/app-release.aab
   ```

4. **Play Console 需要準備的資料**
   - 資料安全性表單：勾選「錄音」用途為**應用程式功能**，並註明
     *不上傳、不儲存*（本 App 只把語音交給系統辨識服務轉文字）
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
