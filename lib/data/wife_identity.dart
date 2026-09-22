import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';

/// 她的身分：名字，以及決定「要不要主動開口要名字」所需的兩個計數。
///
/// 刻意做成不可變的純資料，讓「該不該問」的判斷可以完全不碰 SharedPreferences
/// 就測得到；讀寫交給 [WifeIdentityStore]。
class WifeIdentity {
  /// 她的名字。null 代表還沒取名——這是合法狀態，不是缺資料。
  final String? name;

  /// 累積完成幾輪對話（含她裝傻的那些）
  final int interactions;

  /// 她主動問名字、被打發掉幾次
  final int promptDeclines;

  const WifeIdentity({
    this.name,
    this.interactions = 0,
    this.promptDeclines = 0,
  });

  static const WifeIdentity empty = WifeIdentity();

  bool get hasName => name != null && name!.isNotEmpty;

  /// 標題要顯示的字：沒取名就沿用 App 名稱
  String get displayName => hasName ? name! : AppConfig.appName;

  /// 把台詞裡的 `{name}` 換成她的名字；還沒取名時退回「我」。
  ///
  /// 這樣設定檔裡的台詞不必分兩套寫，取名前後都讀得通。
  String personalize(String line) =>
      line.replaceAll('{name}', hasName ? name! : '我');

  /// 這一刻她該不該主動開口要名字。
  ///
  /// 門檻會隨著被打發的次數往後推，所以「再說吧」之後不會下一輪又問；
  /// 打發滿 [AppConfig.maxNamingPromptDeclines] 次就永久不再主動問，
  /// 只留關鍵字與長按標題兩個使用者自己找上門的入口。
  bool get shouldOfferNaming {
    if (hasName) return false;
    if (promptDeclines >= AppConfig.maxNamingPromptDeclines) return false;
    final threshold = AppConfig.namingPromptAfter +
        promptDeclines * AppConfig.namingPromptCooldown;
    return interactions >= threshold;
  }

  WifeIdentity copyWith({
    String? name,
    bool clearName = false,
    int? interactions,
    int? promptDeclines,
  }) {
    return WifeIdentity(
      name: clearName ? null : (name ?? this.name),
      interactions: interactions ?? this.interactions,
      promptDeclines: promptDeclines ?? this.promptDeclines,
    );
  }
}

/// [WifeIdentity] 的存取。這是全 App 唯一會寫進裝置的東西。
class WifeIdentityStore {
  static const String _nameKey = 'wife_name';
  static const String _interactionsKey = 'wife_interactions';
  static const String _declinesKey = 'wife_naming_declines';

  Future<WifeIdentity> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_nameKey);
    return WifeIdentity(
      name: (stored == null || stored.isEmpty) ? null : stored,
      interactions: prefs.getInt(_interactionsKey) ?? 0,
      promptDeclines: prefs.getInt(_declinesKey) ?? 0,
    );
  }

  Future<void> save(WifeIdentity identity) async {
    final prefs = await SharedPreferences.getInstance();
    if (identity.hasName) {
      await prefs.setString(_nameKey, identity.name!);
    } else {
      await prefs.remove(_nameKey);
    }
    await prefs.setInt(_interactionsKey, identity.interactions);
    await prefs.setInt(_declinesKey, identity.promptDeclines);
  }
}
