import 'dart:math';

import '../core/app_config.dart';
import '../data/naming_config.dart';
import 'mishear_engine.dart';

/// 取名環節的文字處理：把辨識結果整理成名字，再扭成她「聽成」的名字。
///
/// 人名的語音辨識本來就不準，這裡不是在修正它，而是把它變成梗：
/// 她聽錯了，然後你可以選擇接受那個聽錯的版本。
///
/// 換字表與贅詞表都放在設定檔（`naming.substitutions` / `naming.strip`），
/// 要加梗不必動這支程式。
class NameMishearer {
  NameMishearer(this._naming, {Random? random}) : _random = random ?? Random();

  final NamingConfig _naming;
  final Random _random;

  /// 把辨識結果整理成能當名字的字串；整不出東西時回 null（改請使用者打字）。
  ///
  /// 使用者很少只講名字本身，多半是「就叫你小咪好不好」，所以要把前後的
  /// 贅詞剝掉。剝完還是太長就截斷——辨識偶爾會把一整段話都送進來。
  String? sanitize(String raw) {
    var text = MishearEngine.normalize(raw);

    // 長的先試，否則「就叫你」會被「就叫」先咬掉一半，留下「你小咪」
    final tokens = _naming.strip
        .map(MishearEngine.normalize)
        .where((t) => t.isNotEmpty)
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    // 剝到不再變短為止（「我想叫你小咪好不好」要剝掉前後兩段）
    for (var pass = 0; pass < 4; pass++) {
      final before = text;
      for (final token in tokens) {
        if (text.length > token.length && text.startsWith(token)) {
          text = text.substring(token.length);
        }
        if (text.length > token.length && text.endsWith(token)) {
          text = text.substring(0, text.length - token.length);
        }
      }
      if (text == before) break;
    }

    if (text.isEmpty) return null;

    final runes = text.runes.toList();
    if (runes.length <= AppConfig.maxWifeNameLength) return text;
    return String.fromCharCodes(
      runes.sublist(0, AppConfig.maxWifeNameLength),
    );
  }

  /// 她聽成的名字。剛好聽對（換字表一個字都對不上）時回 null。
  String? mishear(String name) {
    final chars = name.runes.map(String.fromCharCode).toList();

    // 先挑出所有換得動的位置，再隨機選一個，這樣同一個名字重取會有不同結果
    final swappable = <int>[];
    for (var i = 0; i < chars.length; i++) {
      final candidates = _naming.substitutions[chars[i]];
      if (candidates != null && candidates.isNotEmpty) swappable.add(i);
    }
    if (swappable.isEmpty) return null;

    final index = swappable[_random.nextInt(swappable.length)];
    final candidates = _naming.substitutions[chars[index]]!;
    final replacement = candidates[_random.nextInt(candidates.length)];

    chars[index] = replacement;
    final result = chars.join();

    // 換完跟原字一樣就當作沒聽錯，不要端出一個「你是說 X 嗎」但 X 就是 X
    return result == name ? null : result;
  }
}
