# 角色形象的下一步：AI 形象與捏人系統

目前畫面上的她是 `PlaceholderCharacter`，底下是 `WifePainter` 的向量繪製
（貝茲曲線、漸層上色、動漫式大眼含高光）。它不吃任何 asset，所以是三層渲染器
最底下永遠可用的保底。

這份文件記錄接下來怎麼換成 AI 生成的形象，以及**捏人（自訂外觀）該怎麼做
才不會爆掉**。

> 調 `WifePainter` 的座標前，先跑
> `flutter test tool/render_character_preview.dart`，
> 它會把六個姿勢畫成 PNG 到 `build/character_preview/`。
> 憑座標想像改出來的東西幾乎都是歪的，一定要看圖。

---

## 一、先講結論

| 階段 | 做什麼 | 成本 | 效果 |
|---|---|---|---|
| **A. 短期** | AI 生 6 張 pose 靜態圖，換掉佔位角色 | 一個下午（程式已就緒，只差圖） | 視覺立刻拉高，但不會動 |
| **B. 中期** | 拿 A 的形象設定圖拆件 → Rive 綁定 | 數天～數週（看綁定熟不熟） | 會動，接上既有 `wife.riv` 契約 |
| **C. 長期** | 捏人：髮型／髮色／瞳色／服裝做成 Rive input | B 完成後才有意義 | 使用者能捏出自己的老婆 |

**順序不能跳。** 捏人系統的前提是「同一具骨架能換皮」，
而骨架來自 B；B 的美術基準來自 A。

---

## 二、為什麼不能直接用 AI 即時生圖

三個理由，任一個都足以否決：

1. **一致性**：擴散模型每次生出來都是不同的人。五個 pose 要看起來是同一個角色，
   靠 prompt 是賭運氣，靠 LoRA／reference 才穩——那已經不是「即時生圖」了。
2. **離線定位**：README 第一句就寫「完全離線、不使用任何語言模型」。
   跑雲端生圖等於推翻這個賣點，也會讓 Play 的資料安全性表單要重填。
3. **延遲**：她聽錯之後要「立刻」開始掃地。等三秒生圖，梗就死了。

> 可接受的折衷：**一次性生成**。安裝後的 onboarding 讓使用者連一次網路，
> 生成／下載屬於自己的那組形象，之後永遠離線跑本機圖。
> 但這要多一份 opt-in 說明與離線 fallback，MVP 之後再談。

---

## 三、階段 A：AI 靜態圖換掉佔位角色 ✅ 程式已就緒

**程式端做完了，現在只差圖。** 把去背 PNG 丟進 `assets/character/default/`，
App 啟動時會自己掃到並改用圖片角色：

```
assets/character/default/
├── idle.png        ← 這張一定要有，沒有就整組不啟用
├── listening.png
├── clean.png       ← 拿掃把
├── lottery.png     ← 戴墨鏡
├── mask.png        ← 敷泥膜
└── confused.png    ← 歪頭
```

缺圖的姿勢會自動退回 `idle.png`，所以**可以一張一張補**，不必一次到齊。
檔名規格與生圖要求見 [`assets/character/default/README.md`](../assets/character/default/README.md)。

動畫也不用做——呼吸與歪頭由 `CharacterMotion` 套在圖片外面，
灰塵特效與號碼卡照舊由舞台疊上去，所以那兩張只要畫人就好。

**生圖要注意的**：同一個 prompt + 固定 seed + 同一份 reference 圖，
六張一起生完再挑，不要今天生兩張明天補三張。角色設定（髮色、瞳色、服裝）
先寫成一段固定文字，往後所有生成都貼同一段。

---

## 四、階段 C：捏人要做成「換 input」，不是「換圖」

這是最容易做錯的地方。兩條路線：

### ❌ 分層貼圖（layered sprite）

髮型 × 髮色 × 服裝 × 5 個 pose，每個組合都要一張圖。
10 髮型 × 8 服裝 × 5 pose = 400 張，而且每加一個 pose 就乘一次。
AI 生得出來，但風格一致性會在第 50 張崩掉。**不要走這條。**

### ✅ Rive 骨架 + 參數化外觀

一具骨架、一套動畫，外觀交給 state machine 的 input 決定：

| 捏人項目 | Rive input | 型別 |
|---|---|---|
| 髮型 | `hairStyle` | Number（0..n，切 nested artboard） |
| 髮色 | `hairHue` | Number（0..360，走 shader/色相位移） |
| 瞳色 | `eyeHue` | Number |
| 服裝 | `outfit` | Number |
| 體型微調 | `bodyScale` | Number |

動畫只綁一次，之後加髮型＝在 nested artboard 多畫一個選項，
**不用重做任何動畫**。這才是捏人系統划得來的形狀。

> 現有的 `docs/rive_state_machine.md` 只定義了 5 個 Trigger。
> 真的要做捏人時，那份契約要補上這張 input 表，並且
> `rive_character.dart` 要多存一組 `SMINumber` 的 reference。

---

## 五、程式的接縫（已經鋪好了）

`CharacterPose` 這層抽象本來就對了，UI 完全不知道底下是誰在畫。
原本的 `bool useRive` 兩種渲染器還夠用、三種就不行，已經換成：

```dart
// lib/ui/widgets/character_renderer.dart
enum CharacterRenderer { placeholder, image, rive }
```

| 檔案 | 責任 |
|---|---|
| `character_renderer.dart` | 啟動時掃素材，決定用誰畫：`rive` → `image` → `placeholder` |
| `image_character.dart` | 圖片角色；檔名契約 `characterImageAsset()`、manifest 掃描 |
| `character_motion.dart` | 呼吸與歪頭，佔位角色與圖片角色共用（新增姿勢只改這裡的 `_tiltFor`） |
| `character_stage.dart` | 依 `CharacterAssets.renderer` 三選一 |

素材偵測走 `AssetManifest.loadFromAssetBundle`，不是逐張 `rootBundle.load`——
後者會把整張 PNG 讀進 cache，只為了問「在不在」太貴。

捏人資料本身是使用者設定，存 `shared_preferences` 即可：
`{ styleId, hairStyle, hairHue, eyeHue, outfit }`，
App 啟動時讀出來餵給渲染器。`kCharacterImageDir` 那個 `default` 字串
就是留給 `styleId` 的位置。

---

## 六、現在的狀態

階段 A 的程式已經鋪好，**下一步是生圖**——一個下午就能讓畫面改頭換面，
而且完全可逆：圖拿掉就自動退回佔位角色。

階段 B、C 先不急。MVP 要驗的是「聽錯這個梗好不好笑」，不是「她好不好看」；
梗成立了再投資綁定與捏人，順序錯了會花一週做骨架然後發現沒人想用。
