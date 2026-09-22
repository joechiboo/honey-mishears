# honey-mishears 專案規則

「AI 老婆」：按住說話 → 語音轉文字 → 關鍵字比對 → 角色裝傻。Flutter / Android 優先。

## 驗證的最低要求

**改完 Dart 一律跑 `flutter analyze`，不能只跑 `flutter test`。**
`flutter test` 只編譯測試檔案 import 到的程式碼——UI 檔案沒有被任何測試 import，
語法錯誤會整個逃過去（實際發生過：25 個測試全過，但 APK 編不起來）。

**`flutter install` 不會因為 build 失敗而中止**，它會安靜地裝上 `build/` 裡的舊 APK。
所以裝完一定要確認裝置上的時間戳真的變了才能說「裝好了」：

```bash
adb shell dumpsys package com.joechiboo.honey_mishears | grep lastUpdateTime
```

**語音相關的改動無法用模擬器或 `flutter test` 驗證**，一定要實機。
模擬器沒有麥克風，也沒有 Android System Intelligence。

## 語音辨識：先讀 docs/speech_recognition.md

這條線有四個坑，**每一個的錯誤訊息都指向錯誤的方向**。動到 `speech_service.dart`、
`speech_model_service.dart` 或 `SpeechModelBridge.kt` 之前先讀那份文件。

最常中的兩個：

- **台灣中文叫 `cmn-Hant-TW`，不叫 `zh-TW`。** 送錯寫法辨識器會安靜地退回 en-US，
  然後報一個看起來像「中文沒裝好」的錯。語系寫法一律以辨識器自己的
  已安裝清單為準（`SpeechModelSupport.deviceTagFor()`）。
- **裝置端辨識器是獨占資源**，漏掉 `destroy()` 之後所有 `startListening` 都回
  `error_busy`，而且**重開 App 不會好**（卡的是系統服務側）。
  卡死時：`adb shell am force-stop com.google.android.as`

## 諧音梗要改設定檔，不要改程式

新增／修改梗一律動 `assets/config/mishear_rules.json`。
只有要新的**舞台特效**（`StageEffect`）或新的**角色姿勢**（`CharacterPose`）才需要寫程式。

新增 `CharacterPose` 時記得四個地方要一起改：enum、`riveTrigger`、
`characterPoseFromTrigger()`、以及各 renderer 的畫法。前三個漏了會編譯錯誤，
第四個漏了只會安靜地沒動畫。

## 不能拿掉的東西

**明牌畫面的娛樂性質聲明**（`lottery_card.dart` 的 `disclaimerText`）是 Google Play
上架合規所需，不要為了畫面清爽拿掉。

**錯誤處理不能跟「裝傻」共用分支。** 角色歪頭裝傻是功能，不是錯誤畫面；
兩者混在一起會讓故障完全隱形（這是花最久才找到的一個 bug）。

## 平行開發

這個 repo 同時有兩條線在跑（語音辨識 / 角色美術），都會動到
`lib/ui/home_page.dart` 與 `lib/ui/widgets/`。同機開兩個 session 時請用 git worktree，
見 `~/.claude/runbooks/git-worktree-parallel-sessions.md`。

已發生過的症狀：對方在寫 adaptive icon 資源時打包，AGP 的增量資源合併狀態會壞掉——
`Unable to locate resourceFile ... in source-sets`，`flutter clean` 後重建即可。

## Android 設定

`compileSdk` / `targetSdk` 34、`minSdk` 21、`ndkVersion 25.1.8937393`（rive_common 要求；
釘住之後 native library 才會正確 strip，APK 從 67MB 降到 25MB）。

release 簽章由 `android/key.properties` 驅動，該檔不進版控；不存在時退回 debug 金鑰。
