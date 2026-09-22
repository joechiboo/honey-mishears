# 語音辨識：架構、實測數據與踩過的坑

> 2026-09-22 在 Galaxy S23（One UI / API 36）上把整條路跑通的紀錄。
>
> **這份文件存在的理由**：這條線上每一個 bug 的錯誤訊息都指向錯誤的方向。
> 不寫下來，換一台手機、或換一個人接手，一定會再走一次同樣的冤枉路。

---

## 一、整條鏈路

```text
按住說話按鈕
   ↓
speech_to_text（Flutter 套件）
   ↓  SpeechRecognizer + EXTRA_LANGUAGE
Android 的預設 RecognitionService
   ↓  這台 S23 上是 com.google.android.as（Android System Intelligence）
SODA（裝置端辨識引擎）
   ↓  需要對應語言的「語言包」才動得起來
辨識文字
   ↓
MishearEngine（純字串比對，完全離線、無模型）
   ↓
角色動畫 + 台詞
```

**回應邏輯真的完全離線**（`MishearEngine` 只做字串比對）；
**語音轉文字則依賴系統的辨識服務與語言包**，這兩件事要分開講，不要混為一談。

---

## 二、S23 實測數據（2026-09-22）

用 `checkRecognitionSupport()` 問出來的原始回報：

```
apiLevel: 36, apiAvailable: true, onDeviceAvailable: true
installed: []                       ← 出廠狀態：一個離線語言包都沒有
pending:   []
supported: [en-US, de-DE, es-ES, fr-FR, it-IT, en-AU, en-GB, en-IE, en-SG,
            ja-JP, de-AT, de-BE, de-CH, en-CA, en-IN, es-US, fr-BE, fr-CA,
            fr-CH, hi-IN, id-ID, it-CH, ko-KR, pt-BR, th-TH,
            cmn-Hans-CN, cmn-Hant-TW, pl-PL, ru-RU, tr-TR, vi-VN]
online:    []                       ← 注意：一個線上語言都沒有
```

三個要記住的事實：

1. **出廠是空的**。不是「缺中文」，是連英文都沒有。第一次用一定失敗。
2. **`online` 是空的**。這台機器上沒有「連網就能辨識」的退路，
   網路好不好跟能不能辨識完全無關。
3. **台灣中文叫 `cmn-Hant-TW`**，不叫 `zh-TW`。見〈坑 2〉。

系統上只有兩個 RecognitionService，**沒有** Google App 的線上辨識器：

```bash
adb shell "pm query-services --brief -a android.speech.RecognitionService"
# com.google.android.as/...AiAiSpeechRecognitionService   ← 預設
# com.anthropic.claude/.bell.assist.ClaudeRecognitionService
```

所以「改用 Google 線上辨識」在這台機器上不是一個選項。

---

## 三、踩過的四個坑

### 坑 1：引擎錯誤偽裝成「聽不懂」

**症狀**：按了沒反應，角色歪頭裝傻。

**真因**：辨識引擎回報錯誤時，程式走進了「沒命中關鍵字」的 fallback 分支。
畫面表現跟「有聽到但沒命中」一模一樣。

這是**四個坑裡最花時間的一個**，因為它讓後面三個坑全部隱形——
看到的永遠是同一個歪頭動作，分不出是壞了還是真的沒聽懂。

**修法**：`_resolve()` 在「有錯誤碼且逐字稿為空」時走獨立分支，直接顯示原因。

> **教訓**：娛樂性質的 fallback（裝傻、賣萌）絕對不能兼任錯誤處理。
> 它會把故障包裝成功能。

### 坑 2：`zh_TW` ≠ `cmn-Hant-TW`

**症狀**：`error_language_unavailable`，App 內面板還宣稱「這台裝置不支援中文」。

**真因**：同一個語言有兩套寫法——

| 誰 | 怎麼稱呼台灣中文 |
|---|---|
| `speech_to_text` 的 `locales()` | `zh_TW`（底線） |
| Android 裝置端辨識器 | `cmn-Hant-TW` |

比對時用「去掉符號比前綴」的偷懶寫法，`zhtw` 對不上 `cmnhanttw`，
於是把「可以下載」誤判成「不支援」。

**修法**：拆成 `語言 / 文字 / 地區` 三段比對，`zh` 與 `cmn` 視為同一語言，
缺的段落視為通配而非不相等。見 `SpeechModelSupport._parse`。

**這個坑有兩側，很容易只修一側**：

- 查詢側：判斷「能不能下載」
- 辨識側：送給 `listen(localeId:)` 的字串

當時只修了查詢側，辨識側繼續送 `zh_TW`，於是撞上坑 3。

### 坑 3：語系字串錯誤會「安靜地」退回 en-US

**症狀**：中文語言包明明裝好了（`installed: [cmn-Hant-TW]`），還是報
`LANGUAGE_PACK_ERROR`。

**真因**：log 裡寫得很清楚，但要找對地方看——

```
I SodaSpeechRecognizer: Initialize Soda [locale: en-US]     ← ???
E SodaSpeechRecognizer: Failed to get language pack of required locale: error 13
```

送進去的 `zh_TW` ASI 解析不了，它**不報錯、不警告**，直接退回預設語系 en-US，
再因為 en-US 的包沒裝而丟出語言包錯誤。

錯誤訊息說「沒有語言包」，而你剛剛才親眼看著中文包裝好——這個矛盾會讓人
往「下載沒成功」「要不要重開機」的方向查，完全偏離真因。

**修法**：語系寫法一律以**辨識器自己的已安裝清單**為準
（`SpeechModelSupport.deviceTagFor()`），`speech_to_text` 的清單只當退路，
且退路一定要把底線換成連字號。

### 坑 4：辨識器是獨占資源，漏放就永久 busy

**症狀**：`error_busy`（顯示為「辨識服務忙碌中」）。**重開 App 也不會好。**

**真因**：`createOnDeviceSpeechRecognizer()` 拿到的是獨占資源。
`destroy()` 原本只寫在部分 callback 裡，只要使用者中途關掉面板、
或下載停在 `onScheduled` 沒有終態，就留下一個綁著系統服務的殭屍。

因為卡住的是**系統服務那一側**，重啟自己的 App 沒有用：

```bash
# 看誰綁著辨識服務
adb shell dumpsys activity services com.google.android.as | grep ConnectionRecord

# 卡死時的解法（ASI 會在下次使用時自動拉起，不影響手機其他功能）
adb shell am force-stop com.google.android.as
```

**修法**：
- Kotlin 側由單一 `liveRecognizer` 欄位持有，`releaseRecognizer()` 統一釋放
- `check()` 加 10 秒保險，callback 不回來也一定放掉
- 對外開 `release` method，Dart 在**開始收音前**與**面板 dispose 時**都呼叫

> **教訓**：`error_busy` 這種名字會讓人以為是對方忙、等一下就好。
> 實際上是自己把資源佔死了，而且症狀會累積——用越多次越壞。

### 附帶：按住／放開的競態

第一次按下要跑「權限 → 初始化 → 查語系 → 收音」，暖機一兩秒。
使用者在暖機期間放手，程式會在 `start()` 回來的瞬間 `stop()`，
換來 `error_client`，連按再撞 `error_busy`。

**修法**：查語系提前到 App 啟動（`prewarm()`，不需要麥克風權限）；
暖機中放手就不 `start`；已 `start` 的改 `cancel()`，並以提示而非錯誤呈現。

---

## 四、怎麼查這類問題

### App 內建的診斷

右上角 **❓ → 語音診斷**：辨識引擎狀態、實際送出的語系、可用語系清單、最後錯誤碼。

### logcat 要撈什麼

```bash
adb logcat -c    # 測之前先清空
# 測完
adb logcat -d | grep -aE "Soda|\[STT\]|\[LangPack\]|RecognitionServiceImpl"
```

判讀重點：

| log | 意義 |
|---|---|
| `[LangPack] check(...) -> {...}` | 裝置回報的四份語言清單（最有價值的一行） |
| `[STT] 送給辨識器的語系 = ?` | 要是 `cmn-Hant-TW`，不能是 `zh_TW` |
| `Initialize Soda [locale: ?]` | 要跟上一行一致；是 `en-US` 就代表語系字串沒被接受 |
| `Initialized SODA with status: 0` | 引擎起來了 |
| `Starting to push audio to Soda` | 真的在收音 |
| `onStartOfSpeech` | 聽到人聲了 |
| `#handleFinalResult: N hyp` | 吐出辨識結果 |

`status=listening` 之後幾毫秒就 `notListening`，代表是**我們自己**把它停掉的，
不是引擎的問題。

### 成功長什麼樣（實測）

```
Initialized SODA with status: 0
Starting to push audio to Soda
RecognitionService#onStartOfSpeech
Audio process finished, transcription completed.
SodaSpeechRecognizer: #handleFinalResult: 1 hyp
```

---

## 五、語言包的下載流程

`speech_to_text` 沒有包 Android 13(API 33) 的這組 API，所以自己接了一層
platform channel（`android/.../SpeechModelBridge.kt`）：

| API | 版本 | 用途 |
|---|---|---|
| `checkRecognitionSupport()` | API 33+ | 問出 installed / pending / supported / online 四份清單 |
| `triggerModelDownload(intent)` | API 33 | 射後不理，沒有任何回報 |
| `triggerModelDownload(intent, executor, listener)` | API 34+ | 有進度與終態回報 |
| `Settings.ACTION_VOICE_INPUT_SETTINGS` | — | 退路：上面都不行時幫使用者開設定頁 |

UI 在 `lib/ui/widgets/language_pack_sheet.dart`，五個狀態：
檢查中 / 缺語音包 / 下載中 / 完成 / 不可能。

最後一個狀態會**列出裝置實際支援的語言**，讓「下載也沒用」這件事當場講清楚，
而不是讓人按半天才發現。

---

## 六、還沒決定的事：要不要改用 Vosk

同事的 [ArgusVoice](https://gitlab.ucl.com.tw/) 專案（`Docs/語音控制評估.md`）走的是
**Vosk 離線小模型 + 語法模式**，把模型包進程式裡，不看系統臉色。

| | 目前（系統辨識） | Vosk |
|---|---|---|
| APK 體積 | 25 MB | 約 67 MB（中文小模型 42 MB） |
| 第一次使用 | 可能要先下載語言包 | 直接可用 |
| 依賴系統 | 高（見上面四個坑） | 無 |
| 辨識品質 | 開放聽寫 | 限定詞彙下更準（見下） |
| 維護 | 官方套件 | 第三方 `vosk_flutter`，要自己驗 |

**Vosk 的關鍵不是模型比較強**——`vosk-model-small-cn-0.22` 自由聽寫的字錯誤率
是 23.5%，很糟。它的優勢來自**語法模式（限定詞彙）**：把問題從「聽寫」
變成「N 選一或都不選」。我們只要辨識三句固定的話，正是它最強的場景。

ArgusVoice 已經踩過、我們可以直接白拿的坑：

1. 語法裡**一定要加 `[unk]`**，否則任何聲音都會被硬塞成你那幾句
2. 中文小模型的詞表是**簡體、以詞為單位**，關鍵字要寫成 `亲 一个` 而非 `親一個`
3. **不要往 `model/` 裡加任何檔案**（Vosk 拿 `graph/words.txt` 當符號表）
4. 單音節短詞誤觸極高；多音節中文詞穩定。「親一個」「抱一個」體質好

**目前的結論**：系統辨識已經可用，Vosk 是**選配不是必須**。
要上架的話值得再評估，判準是「能不能接受部分使用者第一次開 App 要先下載語言包」。

> ⚠️ 本文件先前一度主張「Vosk 是唯一能出貨的做法」，那是基於坑 2 的錯誤判斷
> （誤以為裝置不支援中文）。證據推翻後已收回。
