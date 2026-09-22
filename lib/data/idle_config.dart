/// 她被晾著太久之後會做的事，對應 mishear_rules.json 裡的 `idle` 區塊。
///
/// 這不是一條梗——沒有關鍵字、沒有諧音，是等待本身觸發的。
/// 所以它不進 rules 陣列，也不會出現在梗圖鑑裡：那本是「你做了什麼」的紀錄，
/// 這個則是「你什麼都沒做」的後果，被收進去反而破壞它被撞見的感覺。
class IdleConfig {
  /// 最後一次互動之後隔多久她開始滑手機。0 或負數代表關掉這個行為。
  final Duration after;

  /// 開始滑手機時說的話，隨機挑一句
  final List<String> lines;

  const IdleConfig({this.after = Duration.zero, this.lines = const []});

  static const IdleConfig empty = IdleConfig();

  /// 設定齊全才啟用；缺了任何一半都當關掉，不要自己補預設值——
  /// 她突然自顧自滑起手機會很怪，這種行為寧可漏掉也不要誤觸發。
  bool get enabled => after > Duration.zero && lines.isNotEmpty;

  factory IdleConfig.fromJson(Map<String, dynamic> json) {
    final seconds = (json['afterSeconds'] as num?)?.toDouble() ?? 0;
    return IdleConfig(
      after: Duration(milliseconds: (seconds * 1000).round()),
      lines: (json['lines'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
