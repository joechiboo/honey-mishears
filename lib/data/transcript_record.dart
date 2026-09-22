/// 一筆要回傳的紀錄。
///
/// **刻意不含的東西**，改這個類別前先讀完這段：
/// - 沒有音檔。上傳的只有辨識完的文字。
/// - 沒有她的名字。那是使用者自己取的，屬於個人資料，跟「哪些話聽不懂」無關。
/// - 沒有明牌號碼。那是本機亂數，回傳沒有任何意義。
/// - 沒有裝置型號、沒有 Android ID。識別只用一個本機產生、可重設的隨機 id。
///
/// 目的很窄：知道**哪些話掉進了「聽不懂」**，好決定下一個梗加什麼關鍵字。
/// 任何超出這個目的的欄位都不該加進來。
class TranscriptRecord {
  const TranscriptRecord({
    required this.transcript,
    required this.matched,
    required this.at,
    this.ruleId,
  });

  /// 語音辨識的結果文字
  final String transcript;

  /// 有沒有命中某條諧音梗規則。false 就是她裝傻了——這些才是要看的。
  final bool matched;

  /// 命中的規則 id；沒命中是 null
  final String? ruleId;

  final DateTime at;

  /// 本機佇列用的格式
  Map<String, dynamic> toJson() => {
        't': transcript,
        'm': matched,
        if (ruleId != null) 'r': ruleId,
        'at': at.toUtc().toIso8601String(),
      };

  static TranscriptRecord fromJson(Map<String, dynamic> json) =>
      TranscriptRecord(
        transcript: json['t'] as String,
        matched: json['m'] as bool,
        ruleId: json['r'] as String?,
        at: DateTime.parse(json['at'] as String),
      );

  /// 送去 Supabase 的一列。欄位名對應 docs/telemetry.md 的建表 SQL。
  Map<String, dynamic> toRow({
    required String deviceId,
    required String appVersion,
  }) =>
      {
        'device_id': deviceId,
        'transcript': transcript,
        'matched': matched,
        'matched_rule_id': ruleId,
        'app_version': appVersion,
        'created_at': at.toUtc().toIso8601String(),
      };
}
