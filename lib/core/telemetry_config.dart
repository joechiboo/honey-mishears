/// 逐字稿回傳的端點設定。
///
/// **金鑰不進版控。** repo 是公開的，Supabase anon key 一旦 commit 就等於
/// 貼在網路上任人取用。所以這裡走 `--dart-define`，在 build 指令上帶入：
///
/// ```bash
/// flutter build apk --release \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
/// ```
///
/// 沒帶就是 [configured] == false，整套上傳靜靜地不做事——
/// 這是刻意的預設：忘記帶金鑰時寧可不傳，也不要噴錯或卡住流程。
///
/// 設定 Supabase 那邊要做什麼（建表、RLS 政策）見 `docs/telemetry.md`。
class TelemetryConfig {
  TelemetryConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// 版本標記，用來分辨某筆紀錄是哪一版產生的。沒帶就是 dev。
  static const String appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

  static const String table = 'transcripts';

  static bool get configured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static Uri get insertEndpoint =>
      Uri.parse('$supabaseUrl/rest/v1/$table');

  /// 本地佇列最多留幾筆。滿了丟最舊的——
  /// 長期離線的裝置不該把 shared_preferences 養成肥檔。
  static const int maxQueued = 200;

  /// 一次送幾筆。批次送是為了省連線次數，不是為了省流量（文字很小）。
  static const int batchSize = 20;
}
