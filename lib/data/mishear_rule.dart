import 'dart:math';

import 'naming_config.dart';

/// 舞台特效類型：角色做出反應時，畫面上要疊加的東西
enum StageEffect {
  /// 沒有特效（例如歪頭裝傻）
  none,

  /// 打掃：灰塵、掃把
  dust,

  /// 報明牌：號碼卡（含娛樂性質聲明）
  lottery,
}

StageEffect stageEffectFromName(String? name) {
  switch (name) {
    case 'dust':
      return StageEffect.dust;
    case 'lottery':
      return StageEffect.lottery;
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

  /// 她「聽成」的詞，例如「清一個」。空字串代表沒有諧音（如 fallback）
  final String mishearAs;

  /// 要送進 Rive 狀態機的 Trigger 名稱
  final String animationTrigger;

  /// 舞台特效
  final StageEffect effect;

  /// 台詞池，每次隨機挑一句，避免重複感
  final List<String> lines;

  /// 看場合的台詞池。key 是「她上一個狀態的規則 id」（例如剛敷完泥膜是 `mask`），
  /// 另有一個特殊 key `repeat` 代表同一條梗連續命中。
  ///
  /// 對得上就用這組，對不上就退回 [lines]——所以沒寫 linesWhen 的規則完全照舊。
  final Map<String, List<String>> linesWhen;

  const MishearRule({
    required this.id,
    required this.label,
    required this.keywords,
    required this.mishearAs,
    required this.animationTrigger,
    required this.effect,
    required this.lines,
    this.linesWhen = const {},
  });

  /// [linesWhen] 裡代表「同一條梗連續命中」的 key
  static const String repeatContext = 'repeat';

  factory MishearRule.fromJson(Map<String, dynamic> json) {
    return MishearRule(
      id: json['id'] as String,
      label: (json['label'] as String?) ?? '',
      keywords:
          (json['keywords'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      mishearAs: (json['mishearAs'] as String?) ?? '',
      animationTrigger: (json['animationTrigger'] as String?) ?? 'idle',
      effect: stageEffectFromName(json['effect'] as String?),
      lines:
          (json['lines'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      linesWhen: {
        for (final entry
            in (json['linesWhen'] as Map<String, dynamic>? ?? {}).entries)
          entry.key: (entry.value as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList(),
      },
    );
  }

  /// 從台詞池隨機挑一句；若沒設定台詞則回傳空字串
  String pickLine(Random random) {
    if (lines.isEmpty) return '';
    return lines[random.nextInt(lines.length)];
  }

  /// 看場合挑台詞。
  ///
  /// [previousRuleId] 是她上一個狀態的規則 id（沒有上一輪就傳 null）。
  /// 優先序：連續命中同一條梗 → 上一個狀態 → 預設台詞池。
  /// `repeat` 排在前面是因為「又清？剛剛不是才清過」比接續上一個狀態更貼近
  /// 剛剛才發生的事。
  String pickLineFor(Random random, String? previousRuleId) {
    if (previousRuleId != null) {
      if (previousRuleId == id) {
        final pool = linesWhen[repeatContext];
        if (pool != null && pool.isNotEmpty) return pool[random.nextInt(pool.length)];
      }
      final pool = linesWhen[previousRuleId];
      if (pool != null && pool.isNotEmpty) return pool[random.nextInt(pool.length)];
    }
    return pickLine(random);
  }
}

/// 整份設定檔
class MishearConfig {
  final int version;

  /// 聽不懂時的預設反應
  final MishearRule fallback;

  /// 所有諧音梗規則，依照陣列順序比對（先命中者優先）
  final List<MishearRule> rules;

  /// 取名環節。取名不是一條「梗」（它會等使用者再說一次話），
  /// 所以不放進 rules，自己一個區塊。
  final NamingConfig naming;

  const MishearConfig({
    required this.version,
    required this.fallback,
    required this.rules,
    this.naming = NamingConfig.empty,
  });

  factory MishearConfig.fromJson(Map<String, dynamic> json) {
    final naming = json['naming'] as Map<String, dynamic>?;
    return MishearConfig(
      version: (json['version'] as num?)?.toInt() ?? 1,
      fallback: MishearRule.fromJson(json['fallback'] as Map<String, dynamic>),
      rules: (json['rules'] as List<dynamic>? ?? [])
          .map((e) => MishearRule.fromJson(e as Map<String, dynamic>))
          .toList(),
      naming: naming == null
          ? NamingConfig.empty
          : NamingConfig.fromJson(naming),
    );
  }
}
