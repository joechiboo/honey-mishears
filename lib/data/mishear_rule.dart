import 'dart:math';

import 'idle_config.dart';

/// 舞台特效類型：角色做出反應時，畫面上要疊加的東西
enum StageEffect {
  /// 沒有特效（例如歪頭裝傻）
  none,

  /// 打掃：灰塵、掃把
  dust,

  /// 報明牌：號碼卡（含娛樂性質聲明）
  lottery,

  /// 床：她坐在上面。分前後兩層畫，被子蓋過她的下半身——
  /// 角色本來就只畫到膝蓋以上，靠這層遮擋才讀得出「坐著」。
  bed,
}

StageEffect stageEffectFromName(String? name) {
  switch (name) {
    case 'dust':
      return StageEffect.dust;
    case 'lottery':
      return StageEffect.lottery;
    case 'bed':
      return StageEffect.bed;
    default:
      return StageEffect.none;
  }
}

/// 一條「諧音梗」規則，對應 assets/config/mishear_rules.json 裡 rules 的一筆
class MishearRule {
  /// 唯一代號，例如 clean / lottery
  final String id;

  /// 給人看的名稱，例如「打掃房間」
  final String label;

  /// 觸發關鍵字；語音辨識結果只要「包含」其中任一個就算命中
  final List<String> keywords;

  /// 梗圖鑑在這條梗還沒被觸發時顯示的謎面。
  ///
  /// 空字串會退回一句通用的場面話。寫的時候要指得到路又不能講破諧音——
  /// 一旦寫成「說親一個」，圖鑑就退回答案本了。
  final String hint;

  /// 她「聽成」的詞，例如「清一個」。空字串代表沒有諧音（如 fallback）
  final String mishearAs;

  /// 要送進 Rive 狀態機的 Trigger 名稱
  final String animationTrigger;

  /// 舞台特效
  final StageEffect effect;

  /// 台詞池，每次隨機挑一句，避免重複感
  final List<String> lines;

  const MishearRule({
    required this.id,
    required this.label,
    required this.keywords,
    this.hint = '',
    required this.mishearAs,
    required this.animationTrigger,
    required this.effect,
    required this.lines,
  });

  factory MishearRule.fromJson(Map<String, dynamic> json) {
    return MishearRule(
      id: json['id'] as String,
      label: (json['label'] as String?) ?? '',
      keywords:
          (json['keywords'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      hint: (json['hint'] as String?) ?? '',
      mishearAs: (json['mishearAs'] as String?) ?? '',
      animationTrigger: (json['animationTrigger'] as String?) ?? 'idle',
      effect: stageEffectFromName(json['effect'] as String?),
      lines:
          (json['lines'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    );
  }

  /// 從台詞池隨機挑一句；若沒設定台詞則回傳空字串
  String pickLine(Random random) {
    if (lines.isEmpty) return '';
    return lines[random.nextInt(lines.length)];
  }
}

/// 整份設定檔
class MishearConfig {
  final int version;

  /// 聽不懂時的預設反應
  final MishearRule fallback;

  /// 所有諧音梗規則，依照陣列順序比對（先命中者優先）
  final List<MishearRule> rules;

  /// 晾太久之後她自己會做的事。沒設定就是關掉。
  final IdleConfig idle;

  const MishearConfig({
    required this.version,
    required this.fallback,
    required this.rules,
    this.idle = IdleConfig.empty,
  });

  factory MishearConfig.fromJson(Map<String, dynamic> json) {
    final idle = json['idle'] as Map<String, dynamic>?;
    return MishearConfig(
      version: (json['version'] as num?)?.toInt() ?? 1,
      fallback: MishearRule.fromJson(json['fallback'] as Map<String, dynamic>),
      rules: (json['rules'] as List<dynamic>? ?? [])
          .map((e) => MishearRule.fromJson(e as Map<String, dynamic>))
          .toList(),
      idle: idle == null ? IdleConfig.empty : IdleConfig.fromJson(idle),
    );
  }
}
