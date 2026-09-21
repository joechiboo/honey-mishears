import 'dart:math';

import '../data/mishear_rule.dart';

/// 一次「聽錯」的結果
class MishearResult {
  /// 語音辨識實際聽到的文字（原文，未正規化）
  final String spokenText;

  /// 命中的規則（沒命中時是 fallback）
  final MishearRule rule;

  /// 這次要說的台詞
  final String line;

  /// 是否真的命中某條梗；false 代表走 fallback（歪頭裝傻）
  final bool matched;

  const MishearResult({
    required this.spokenText,
    required this.rule,
    required this.line,
    required this.matched,
  });
}

/// 諧音梗比對引擎：語音文字 → 規則
///
/// 刻意做得很笨：純字串包含比對，不用任何語言模型，完全離線。
class MishearEngine {
  MishearEngine(this._config, {Random? random}) : _random = random ?? Random();

  final MishearConfig _config;
  final Random _random;

  /// 正規化：去掉標點、空白，只留中日文字、英數字。
  /// 這樣「親一個！」「親　一個」都能對上關鍵字「親一個」。
  static String normalize(String input) {
    return input.replaceAll(RegExp(r'[^\u4e00-\u9fff\u3040-\u30ff0-9a-zA-Z]'), '');
  }

  MishearResult interpret(String spokenText) {
    final normalized = normalize(spokenText);

    if (normalized.isNotEmpty) {
      for (final rule in _config.rules) {
        for (final keyword in rule.keywords) {
          final key = normalize(keyword);
          if (key.isNotEmpty && normalized.contains(key)) {
            return MishearResult(
              spokenText: spokenText,
              rule: rule,
              line: rule.pickLine(_random),
              matched: true,
            );
          }
        }
      }
    }

    // 沒有命中任何梗 → 歪頭裝傻
    final fallback = _config.fallback;
    return MishearResult(
      spokenText: spokenText,
      rule: fallback,
      line: fallback.pickLine(_random),
      matched: false,
    );
  }
}
