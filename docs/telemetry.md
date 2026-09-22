# 逐字稿回傳

目的很窄：**知道哪些話掉進了「聽不懂」**，好決定下一個梗加什麼關鍵字。
這份文件是設定步驟與邊界。

---

## 一、收什麼、不收什麼

| | |
|---|---|
| ✅ 收 | 語音辨識完的**文字**、有沒有命中規則、命中哪一條、App 版本、時間 |
| ✅ 收 | 一個本機隨機產生的 `device_id`（UUID v4，可重設） |
| ❌ 不收 | **錄音**。音檔從來沒有離開裝置，也沒有被存下來 |
| ❌ 不收 | 使用者替她取的**名字**。那是個人資料，跟「哪些話聽不懂」無關 |
| ❌ 不收 | 明牌號碼（本機亂數，傳了沒意義）、裝置型號、Android ID、位置 |

欄位就是六個，寫死在 `lib/data/transcript_record.dart` 的 `toRow()`，
並且有一條測試盯著「只該有這六個——多一個就是多收資料」。
**要加欄位前先回來讀這一節。**

---

## 二、Supabase 這邊要做的事

### 1. 建表

到專案的 SQL Editor 貼這段：

```sql
create table public.transcripts (
  id              bigint generated always as identity primary key,
  device_id       uuid        not null,
  transcript      text        not null,
  matched         boolean     not null,
  matched_rule_id text,
  app_version     text,
  created_at      timestamptz not null default now()
);

-- 查「最常聽不懂的話」會掃這兩個欄位
create index transcripts_missed_idx
  on public.transcripts (matched, created_at desc);
```

### 2. RLS：只給寫，不給讀

**這一步不能跳。** anon key 會被打包進 APK，任何人拆開 APK 都拿得到，
所以「不給讀」的政策是唯一的防線：最壞情況是有人灌垃圾資料進來，
而不是把所有人說過的話撈走。

```sql
alter table public.transcripts enable row level security;

-- 只能 insert。沒有 select 政策 → anon 讀不到任何一列
create policy "anon can insert transcripts"
  on public.transcripts
  for insert
  to anon
  with check (true);
```

驗證方式：用 anon key 打一次 `GET /rest/v1/transcripts`，
應該回空陣列或 401，**不能**回到資料。

### 3. 拿 URL 與 anon key

Project Settings → API：
- `Project URL` → `SUPABASE_URL`
- `anon public` → `SUPABASE_ANON_KEY`

---

## 三、打包時帶進去

**金鑰不進版控**（repo 是公開的），所以走 `--dart-define`：

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi... \
  --dart-define=APP_VERSION=1.0.0
```

**沒帶就不會傳送任何東西**（`TelemetryConfig.configured` 為 false），
設定面板也會顯示「這一版沒有設定回傳端點」。這是刻意的預設：
忘記帶金鑰時寧可不傳，也不要噴錯或卡住流程。

平常開發直接 `flutter run` 不帶 define 就好，不會污染資料。

> 金鑰放哪：建議存在 `~/.honey-mishears-telemetry.env` 之類的檔案，
> 或用密碼管理員。**不要** 寫進 repo 裡任何檔案，包含 shell script。

---

## 四、同意機制

預設**開**，使用者可以關。實作上是三件事：

1. **首次啟動一次告知**（`showTelemetryNotice`）：說明收什麼、不收什麼，
   「不要傳送」跟「知道了」是同等大小的兩個按鈕，不是一行小字
2. **右上角設定隨時可關**（`TelemetrySheet`）
3. **關掉就連還沒送出的一起刪**（`TelemetryStore.setEnabled`）——
   留著等下次開啟才送，等於沒有真的尊重那個關閉動作

設定面板同時**列出還沒送出去的內容**。這是那個面板存在的主要理由：
只給一個開關、不讓人看到內容，等於要使用者憑信任。

---

## 五、Play Console 要跟著改

⚠️ 加了這個功能之後，**資料安全性表單必須更新**，原本宣告的是
「錄音用途為應用程式功能，不上傳、不儲存」：

| 項目 | 要怎麼填 |
|---|---|
| 資料類型 | 「應用程式活動 → 其他使用者產生的內容」 |
| 是否蒐集 | **是** |
| 是否傳輸至第三方 | 是（Supabase） |
| 用途 | 應用程式功能 / 分析 |
| 是否必要 | **選用**（使用者可以關） |
| 加密傳輸 | 是（HTTPS） |
| 可否要求刪除 | 要提供聯絡方式 |
| 錄音 | 仍然是「不蒐集」——音檔確實沒有離開裝置 |

另外需要一份**隱私政策**並填進 Play Console。內容至少要涵蓋：
收什麼、為什麼收、存在哪（Supabase，區域）、留多久、怎麼要求刪除。

---

## 六、怎麼看資料

最常聽不懂的話：

```sql
select transcript, count(*) as n
from public.transcripts
where not matched
group by transcript
order by n desc
limit 50;
```

哪條規則最常被觸發：

```sql
select matched_rule_id, count(*) as n
from public.transcripts
where matched
group by matched_rule_id
order by n desc;
```

命中率隨版本的變化（加了新梗之後應該要上升）：

```sql
select app_version,
       round(100.0 * sum(case when matched then 1 else 0 end) / count(*), 1)
         as hit_rate
from public.transcripts
group by app_version
order by app_version;
```

看到某句常出現在「聽不懂」清單裡，就去
[`assets/config/mishear_rules.json`](../assets/config/mishear_rules.json)
把它加進某條規則的 `keywords`——不必改程式。

---

## 七、保留期限

Supabase 不會自己刪。建議設一條定期清理，別無限期堆著：

```sql
delete from public.transcripts
where created_at < now() - interval '180 days';
```

排程可以用 Supabase 的 Cron（Database → Cron Jobs）。
這件事也要寫進隱私政策的「留多久」。
