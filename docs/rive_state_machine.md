# Rive 狀態機規劃

這份文件是**美術與程式之間的契約**。只要照這裡的命名做，把檔案丟進
`assets/rive/wife.riv`，App 會自動偵測並從佔位角色切換到 Rive 角色，
不需要改任何程式碼。

---

## 一、命名契約（最重要，名字錯了就接不上）

| 項目 | 名稱 | 程式對應位置 |
|---|---|---|
| 檔案 | `wife.riv` | `lib/ui/widgets/rive_character.dart` → `kRiveAssetPath` |
| Artboard | 任意（程式用預設 artboard） | — |
| State Machine | `WifeStateMachine` | `kRiveStateMachine` |
| Trigger | `idle` / `listen` / `clean` / `lottery` / `mask` / `bundle` / `confuse` | `CharacterPose.riveTrigger` |

> 程式送的是 **Trigger**（不是 Boolean、不是 Number）。
> 找不到對應 trigger 時程式不會崩潰，只會在 log 印一行警告、角色留在原狀態。

---

## 二、狀態（States）

狀態機建議只做**一層 Layer**，七個狀態互相可達：

| State | 進入時機 | 動作描述 | 循環 |
|---|---|---|---|
| `Idle` | 預設狀態、每段反應播完後回到這裡 | 呼吸起伏、偶爾眨眼、髮絲微動 | ✅ Loop |
| `Listening` | 使用者按住按鈕 | 身體微微前傾、眼睛睜大、手靠近耳邊 | ✅ Loop |
| `Cleaning` | 聽成「清一個」 | 捲袖子 → 拿起掃把 → 來回掃地 | ✅ Loop |
| `Lottery` | 聽成「報一個」 | 戴上墨鏡（一次性）→ 抱胸點頭的自信待機 | 前段 One-shot，後段 Loop |
| `Mask` | 聽成「泥好」 | 貼上白色片狀面膜（一次性）→ 閉眼放鬆的敷臉待機 | 前段 One-shot，後段 Loop |
| `Bundled` | 聽成「包緊我」 | 拿外套穿上、把圍巾繞兩圈（一次性）→ 包成一團的小幅晃動 | 前段 One-shot，後段 Loop |
| `Confused` | 聽不懂 | 歪頭、頭上冒問號、眨兩下眼 | ✅ Loop（幅度小） |

### 為什麼反應狀態要 Loop？

App 不會主動把她切回 `Idle`——使用者下一次按住說話時才會送 `listen`。
所以每個反應狀態都要能「無限待著也不尷尬」，避免播完卡在最後一格。

---

## 三、轉場（Transitions）

從**任一狀態**都要能被 trigger 打斷，也就是每個 trigger 都需要 7 條轉場
（或用 Rive 的 `Any State` 節點一次搞定，**建議用 Any State**）：

```
Any State ──[idle]────▶ Idle
Any State ──[listen]──▶ Listening
Any State ──[clean]───▶ Cleaning
Any State ──[lottery]─▶ Lottery
Any State ──[mask]────▶ Mask
Any State ──[bundle]──▶ Bundled
Any State ──[confuse]─▶ Confused
```

轉場參數建議：

- **Duration**：150–250ms（太快會跳、太慢會覺得她反應遲鈍）
- **Exit Time**：關閉。使用者放開按鈕就該立刻反應，不能等動畫播完
- `Any State` 記得取消勾選 "Can transition to self"，避免同狀態重複觸發時抖動

---

## 四、分鏡重點（笑點在這裡）

核心設定是**她一本正經地誤會**，所以動畫要避免任何「我知道我在裝傻」的暗示：

- ❌ 不要眨眼示意、不要吐舌、不要偷笑
- ✅ 表情要認真、動作要果斷，像真的在做一件正事
- `Cleaning` 進場時那個「捲袖子」的動作最好做滿 0.5 秒——理直氣壯的準備動作
  比掃地本身更好笑
- `Lottery` 戴墨鏡要「唰」地一下，配一個定格

---

## 五、Rive 之前的兩層替代方案

App 有三種渲染器，啟動時掃素材決定用誰，三者吃同一組 `CharacterPose`：

| 優先序 | 渲染器 | 條件 | 表現 |
|---|---|---|---|
| 1 | Rive | `assets/rive/wife.riv` 存在 | 完整動畫，本文件規格 |
| 2 | 圖片 | `assets/character/default/idle.png` 存在 | 一個姿勢一張靜態圖，只有呼吸與歪頭 |
| 3 | 佔位角色 | 永遠可用的保底 | `WifePainter` 的向量繪製，只有呼吸與歪頭 |

**`wife.riv` 一放進去就是最優先**，會蓋過圖片角色，不必先把圖刪掉。
判斷邏輯在 `lib/ui/widgets/character_renderer.dart`。

佔位角色（`painters/wife_painter.dart`）各姿勢的表現，可以拿來當分鏡參考：
用 `flutter test tool/render_character_preview.dart` 可以把六張畫出來看：

| CharacterPose | 佔位角色的表現 |
|---|---|
| `idle` | 呼吸縮放 |
| `listening` | 眼睛變大、身體微傾 |
| `clean` | 左右擺動 + 🧹 emoji 擺盪 + 灰塵粒子 |
| `lottery` | 黑色墨鏡橫條 + 號碼卡浮現 |
| `mask` | 白色片狀面膜、眼洞裡閉著眼 |
| `bundled` | 換成薰衣草色外套 + 圍巾蓋住嘴 |
| `confused` | 固定歪頭 + ❓ emoji |

> 呼吸與歪頭是 `character_motion.dart` 套在外面的，圖片角色也吃這一套。
> **Rive 角色不吃**——動作全由狀態機自己負責，不會被外面再轉一次。

---

## 六、匯出設定

- 在 Rive 編輯器 **Export → Runtime (.riv)**
- 勾選 state machine 一起匯出
- 檔案盡量壓在 500KB 以內（App 啟動時整份載入記憶體）
- 圖片素材請用 Rive 內建的向量繪製，避免嵌入大張點陣圖
