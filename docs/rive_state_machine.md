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
| Trigger | `idle` / `listen` / `clean` / `lottery` / `confuse` | `CharacterPose.riveTrigger` |

> 程式送的是 **Trigger**（不是 Boolean、不是 Number）。
> 找不到對應 trigger 時程式不會崩潰，只會在 log 印一行警告、角色留在原狀態。

---

## 二、狀態（States）

狀態機建議只做**一層 Layer**，五個狀態互相可達：

| State | 進入時機 | 動作描述 | 循環 |
|---|---|---|---|
| `Idle` | 預設狀態、每段反應播完後回到這裡 | 呼吸起伏、偶爾眨眼、髮絲微動 | ✅ Loop |
| `Listening` | 使用者按住按鈕 | 身體微微前傾、眼睛睜大、手靠近耳邊 | ✅ Loop |
| `Cleaning` | 聽成「清一個」 | 捲袖子 → 拿起掃把 → 來回掃地 | ✅ Loop |
| `Lottery` | 聽成「報一個」 | 戴上墨鏡（一次性）→ 抱胸點頭的自信待機 | 前段 One-shot，後段 Loop |
| `Confused` | 聽不懂 | 歪頭、頭上冒問號、眨兩下眼 | ✅ Loop（幅度小） |

### 為什麼反應狀態要 Loop？

App 不會主動把她切回 `Idle`——使用者下一次按住說話時才會送 `listen`。
所以每個反應狀態都要能「無限待著也不尷尬」，避免播完卡在最後一格。

---

## 三、轉場（Transitions）

從**任一狀態**都要能被 trigger 打斷，也就是每個 trigger 都需要 5 條轉場
（或用 Rive 的 `Any State` 節點一次搞定，**建議用 Any State**）：

```
Any State ──[idle]────▶ Idle
Any State ──[listen]──▶ Listening
Any State ──[clean]───▶ Cleaning
Any State ──[lottery]─▶ Lottery
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

## 五、目前的替代方案

Rive 素材完成前，App 使用 `lib/ui/widgets/placeholder_character.dart`：
純 Flutter 圖形畫的簡易角色，吃同一組 `CharacterPose`。

| CharacterPose | 佔位角色的表現 |
|---|---|
| `idle` | 呼吸縮放 |
| `listening` | 眼睛變大、身體微傾 |
| `clean` | 左右擺動 + 🧹 emoji 擺盪 + 灰塵粒子 |
| `lottery` | 黑色墨鏡橫條 + 號碼卡浮現 |
| `confused` | 固定歪頭 + ❓ emoji |

切換方式：把 `wife.riv` 放進 `assets/rive/` 即可，程式啟動時會自動偵測
（`isRiveAssetAvailable()`），不必改設定。

---

## 六、匯出設定

- 在 Rive 編輯器 **Export → Runtime (.riv)**
- 勾選 state machine 一起匯出
- 檔案盡量壓在 500KB 以內（App 啟動時整份載入記憶體）
- 圖片素材請用 Rive 內建的向量繪製，避免嵌入大張點陣圖
