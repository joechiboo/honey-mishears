# 角色生圖 Prompt 包

六張圖的 prompt，直接複製貼上就能用。
產出的 PNG 放進 [`assets/character/default/`](../assets/character/default/README.md)。

**核心規則：角色設定段每次都貼一模一樣的，只換動作那一句。**
六張要看起來是同一個人，靠的就是這段文字不動。

---

## 一、角色設定段（六張共用，不要改）

配色取自 `lib/core/app_theme.dart`，讓她跟 App 的介面是同一組色。

> A cute 2D anime-style young woman, warm and homey vibe.
> Long chocolate-brown hair (#6E4B3A) with straight blunt bangs, soft large
> eyes, small rosy blush on both cheeks, gentle smile.
> Wearing a soft pink house dress (#F7C8D0) with short sleeves.
> Flat cel-shaded illustration, clean uniform line art, soft minimal shading,
> pastel palette, kawaii but not childish.
> Full body, centered, facing viewer.
> **Transparent background, no background elements, no shadow on the ground.**

中文版（給吃中文比較準的模型）：

> 可愛的 2D 日系動漫風年輕女性，溫柔居家感。
> 巧克力棕色長髮（#6E4B3A）、齊瀏海，柔和大眼，雙頰淡淡腮紅，微笑。
> 穿粉色短袖居家連身裙（#F7C8D0）。
> 扁平賽璐璐上色、乾淨均勻的線稿、柔和的少量陰影、粉彩色調，可愛但不幼稚。
> 全身、置中、面向鏡頭。
> **透明背景，不要任何背景元素，地上不要影子。**

---

## 二、六個動作（各接在設定段後面）

| 檔名 | 接在設定段後面的動作句 |
|---|---|
| `idle.png` | Standing relaxed, arms naturally at her sides, calm gentle smile. |
| `listening.png` | Leaning slightly forward, eyes wide with interest, one hand cupped behind her ear, listening attentively. |
| `clean.png` | Sleeves rolled up, holding a broom with both hands, energetic determined expression, mid-sweep pose. |
| `lottery.png` | Wearing black sunglasses, arms crossed confidently, smug knowing smirk. |
| `mask.png` | Face fully covered in a green clay mask, two cucumber slices over her eyes, relaxed spa expression, hands resting. |
| `confused.png` | Head tilted to one side, puzzled expression, one finger on her chin, slightly raised eyebrow. |

> ⚠️ 檔名跟的是程式裡 `CharacterPose` 的 enum 名稱，
> 所以是 `listening.png` / `confused.png`，**不是** `listen` / `confuse`。

**這兩張不用畫多餘的東西**：
- `clean.png` 的灰塵是程式用 `DustEffect` 疊上去的，只要畫人拿掃把
- `lottery.png` 的號碼卡是程式疊的，只要畫她戴墨鏡的樣子

---

## 三、負面 prompt（會生出雜物的模型才需要）

> background, scenery, room, furniture, floor, shadow, text, watermark,
> signature, multiple characters, cropped, out of frame, realistic, 3d render

---

## 四、輸出規格

| 項目 | 規格 |
|---|---|
| 尺寸 | 520 × 600（顯示 260 × 300 的 2x） |
| 格式 | PNG，**透明背景** |
| 構圖 | 置中，四周留邊，不要頂到畫布 |
| 檔案大小 | 單張 300KB 以內 |

多數模型不會直接吐透明背景，通常要**生完再去背**
（`rembg`、Photoshop 的移除背景、或線上去背工具都行）。
去背後記得檢查髮絲邊緣有沒有殘留白邊——App 的背景是粉色光暈，白邊會很明顯。

---

## 五、生完檢查這幾件事

- [ ] 六張是**同一個人**：髮色、瀏海、裙子顏色一致
- [ ] 背景真的透明（不是白色方塊）
- [ ] 人物在畫布中間，沒被裁到手或腳
- [ ] `idle.png` 一定要有——沒有它整組不會啟用
- [ ] 檔名拼對：`listening` / `confused`，不是 `listen` / `confuse`

放進資料夾後直接 `flutter run`，不用改任何程式碼。
畫面沒變就是檔名錯了或 `idle.png` 沒放到。

---

## 六、之後要加姿勢的話

流程是：`CharacterPose` 加一個值 → `character_motion.dart` 的 `_tiltFor`
補一筆傾斜 → 回來這份文件加一列動作句 → 用**同一段設定**生新的那張。

設定段不要重寫。時間久了忘記當初怎麼寫的，臉就會慢慢跑掉。
