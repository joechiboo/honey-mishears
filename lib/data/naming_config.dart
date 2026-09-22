import 'dart:math';

/// 取名環節的設定，對應 assets/config/mishear_rules.json 裡的 `naming` 區塊。
///
/// 取名跟諧音梗一樣，內容全部走設定檔——台詞、觸發語、她會把哪個字聽錯，
/// 都不必動程式。程式這邊只負責流程。
class NamingConfig {
  /// 使用者主動要求取名的觸發語，例如「你叫什麼名字」
  final List<String> keywords;

  /// 她自己開口要名字時說的話
  final List<String> offer;

  /// 進入取名模式、等使用者把名字說出來時說的話
  final List<String> prompt;

  /// 完全沒聽到東西時說的話（接著會端出文字輸入）
  final List<String> unheard;

  /// 名字定下來之後說的話；可用 `{name}`
  final List<String> accepted;

  /// 她會把人名的哪個字聽成什麼。
  /// key 是使用者說的字，value 是她可能聽成的字（隨機挑一個）。
  final Map<String, List<String>> substitutions;

  /// 要從辨識結果前後剝掉的贅詞。
  /// 使用者很少只說「小咪」，通常是「就叫你小咪好不好」。
  final List<String> strip;

  const NamingConfig({
    this.keywords = const [],
    this.offer = const [],
    this.prompt = const [],
    this.unheard = const [],
    this.accepted = const [],
    this.substitutions = const {},
    this.strip = const [],
  });

  static const NamingConfig empty = NamingConfig();

  factory NamingConfig.fromJson(Map<String, dynamic> json) {
    List<String> strings(String key) =>
        (json[key] as List<dynamic>? ?? []).map((e) => e.toString()).toList();

    final rawSubs = json['substitutions'] as Map<String, dynamic>? ?? {};
    return NamingConfig(
      keywords: strings('keywords'),
      offer: strings('offer'),
      prompt: strings('prompt'),
      unheard: strings('unheard'),
      accepted: strings('accepted'),
      strip: strings('strip'),
      substitutions: {
        for (final entry in rawSubs.entries)
          entry.key: (entry.value as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList(),
      },
    );
  }

  // 取台詞。設定檔沒寫時退回內建的一句，讓流程不會出現空白對話框。
  String offerLine(Random random) =>
      _pick(offer, random, '對了…我好像還沒有名字耶。');
  String promptLine(Random random) =>
      _pick(prompt, random, '你想叫我什麼？按住按鈕跟我說。');
  String unheardLine(Random random) =>
      _pick(unheard, random, '這次我真的沒聽到，你直接打給我看好不好？');
  String acceptedLine(Random random) =>
      _pick(accepted, random, '{name}…嗯，我喜歡這個名字。');

  static String _pick(List<String> pool, Random random, String fallback) =>
      pool.isEmpty ? fallback : pool[random.nextInt(pool.length)];
}
