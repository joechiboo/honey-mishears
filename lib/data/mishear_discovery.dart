import 'package:shared_preferences/shared_preferences.dart';

/// 使用者已經親手觸發過的梗，梗圖鑑靠它決定哪幾筆還蓋著。
///
/// 跟 [WifeIdentity] 一樣刻意做成不可變資料：「這筆解鎖了沒」的判斷
/// 完全不必碰 SharedPreferences 就測得到。
class MishearDiscovery {
  /// 已解鎖的規則 id。用設定檔的 id 而不是索引，
  /// 這樣之後在 rules 陣列中間插一條新梗，舊的解鎖紀錄不會錯位。
  final Set<String> ids;

  const MishearDiscovery(this.ids);

  static const MishearDiscovery empty = MishearDiscovery(<String>{});

  bool has(String ruleId) => ids.contains(ruleId);

  int get count => ids.length;

  /// 回傳解鎖後的新集合；本來就解鎖過的話回傳自己，
  /// 呼叫端可以用 `identical` 判斷這輪是不是「第一次發現」。
  MishearDiscovery unlock(String ruleId) =>
      ids.contains(ruleId) ? this : MishearDiscovery({...ids, ruleId});
}

/// [MishearDiscovery] 的存取
class MishearDiscoveryStore {
  static const String _key = 'discovered_mishears';

  Future<MishearDiscovery> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key);
    if (stored == null || stored.isEmpty) return MishearDiscovery.empty;
    return MishearDiscovery(stored.toSet());
  }

  Future<void> save(MishearDiscovery discovery) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, discovery.ids.toList());
  }
}
