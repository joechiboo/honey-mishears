import 'package:shared_preferences/shared_preferences.dart';

import 'mishear_rule.dart';

/// 兩個人之間已經發生過的事。
///
/// 這裡刻意不叫「成就」：成就是系統在對玩家講話，冷的、要收集滿的，
/// 看到 3/4 只會想把剩下那個清掉。回憶是她在跟你講一起做過的事，
/// 沒集滿也不欠誰。同一份資料，換個名字就換掉整個語氣。
///
/// 跟 [WifeIdentity] 一樣做成不可變資料：「這件事發生過沒」的判斷
/// 完全不必碰 SharedPreferences 就測得到。
class Memories {
  /// 已經發生過的事的 id，格式見 [MemoryId]
  final Set<String> ids;

  const Memories(this.ids);

  static const Memories empty = Memories(<String>{});

  bool has(String memoryId) => ids.contains(memoryId);

  int get count => ids.length;

  /// 回傳記住之後的新集合；本來就記得的話回傳自己，
  /// 呼叫端可以用 `identical` 判斷這輪是不是「第一次」。
  Memories remember(String memoryId) =>
      ids.contains(memoryId) ? this : Memories({...ids, memoryId});
}

/// 回憶的 id。
///
/// 帶前綴是為了讓不同種類的回憶共用同一份儲存：諧音梗是一種來源，
/// 取名是另一種，之後還會有第三種。前綴一旦寫進使用者的手機就不能改，
/// 改了等於把人家的回憶整批清掉。
class MemoryId {
  MemoryId._();

  /// 某一條諧音梗被說中過。用規則 id 而不是索引，
  /// 這樣之後在 rules 中間插一條新梗，舊的回憶不會錯位。
  static String rule(String ruleId) => 'rule:$ruleId';

  /// 她有名字了
  static const String naming = 'milestone:naming';
}

/// 回憶簿上的一筆。
///
/// 梗與里程碑最後都收斂成這個形狀，所以簿子本身不必知道回憶從哪來。
class MemoryEntry {
  /// 存進 [Memories] 用的 id
  final String id;

  /// 已經發生過時顯示的標題
  final String title;

  /// 已經發生過時顯示的第二行
  final String detail;

  /// 還沒發生時顯示的那句話。要指得到路又不能講破——
  /// 一旦寫成「說親一個」，這本就退回答案本了。
  final String hint;

  const MemoryEntry({
    required this.id,
    required this.title,
    required this.detail,
    required this.hint,
  });
}

/// 把諧音梗規則攤成回憶簿上的條目。
///
/// 取名那一則不在這裡：它不是梗、沒有關鍵字，由 home_page 接上她現在的
/// 名字之後自己追加一筆（見 [MemoryId.naming]）。
List<MemoryEntry> memoryEntriesForRules(MishearConfig config) {
  return [
    for (final rule in config.rules)
      MemoryEntry(
        id: MemoryId.rule(rule.id),
        title: rule.keywords.join('、'),
        detail: '她聽成「${rule.mishearAs}」，然後${rule.label}',
        hint: rule.hint.isEmpty ? '還沒說出口的一句話。' : rule.hint,
      ),
  ];
}

/// [Memories] 的存取
class MemoryStore {
  static const String _key = 'memories';

  Future<Memories> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key);
    if (stored == null || stored.isEmpty) return Memories.empty;
    return Memories(stored.toSet());
  }

  Future<void> save(Memories memories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, memories.ids.toList());
  }
}
