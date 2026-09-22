import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:honey_mishears/data/mishear_repository.dart';
import 'package:honey_mishears/data/mishear_rule.dart';
import 'package:honey_mishears/services/mishear_engine.dart';

/// 測試用的假設定檔，不依賴真正的 JSON
MishearConfig _testConfig() => const MishearConfig(
      version: 1,
      fallback: MishearRule(
        id: 'confused',
        label: '聽不懂',
        keywords: [],
        mishearAs: '',
        animationTrigger: 'confuse',
        effect: StageEffect.none,
        lines: ['嗯？'],
      ),
      rules: [
        MishearRule(
          id: 'clean',
          label: '打掃房間',
          keywords: ['親一個', '親親'],
          mishearAs: '清一個',
          animationTrigger: 'clean',
          effect: StageEffect.dust,
          lines: ['清一個？好呀。'],
        ),
        MishearRule(
          id: 'lottery',
          label: '報明牌',
          keywords: ['抱一個'],
          mishearAs: '報一個',
          animationTrigger: 'lottery',
          effect: StageEffect.lottery,
          lines: ['報一個是吧？'],
        ),
      ],
    );

void main() {
  final engine = MishearEngine(_testConfig(), random: Random(1));

  group('關鍵字比對', () {
    test('完全相符會命中', () {
      final result = engine.interpret('親一個');
      expect(result.matched, isTrue);
      expect(result.rule.id, 'clean');
      expect(result.rule.mishearAs, '清一個');
    });

    test('關鍵字被包在句子裡也算命中', () {
      expect(engine.interpret('老婆親一個啦').rule.id, 'clean');
    });

    test('標點與空白會被忽略', () {
      expect(engine.interpret('親　一 個！').rule.id, 'clean');
      expect(engine.interpret('抱一個，好不好？').rule.id, 'lottery');
    });

    test('同一條規則的多組關鍵字都要能命中', () {
      expect(engine.interpret('親親').rule.id, 'clean');
    });
  });

  group('聽不懂時走 fallback', () {
    test('沒命中任何關鍵字', () {
      final result = engine.interpret('今天天氣真好');
      expect(result.matched, isFalse);
      expect(result.rule.id, 'confused');
      expect(result.rule.animationTrigger, 'confuse');
    });

    test('辨識不到內容（空字串）', () {
      final result = engine.interpret('');
      expect(result.matched, isFalse);
      expect(result.rule.id, 'confused');
    });

    test('只有標點也算聽不懂', () {
      expect(engine.interpret('？？！').matched, isFalse);
    });
  });

  group('台詞', () {
    test('一定來自該規則的台詞池', () {
      final result = engine.interpret('親一個');
      expect(result.rule.lines, contains(result.line));
    });
  });

  group('正規化', () {
    test('保留中文與英數，去掉其餘字元', () {
      expect(MishearEngine.normalize('親一個！！ ok 123'), '親一個ok123');
    });
  });

  group('實際的設定檔', () {
    // rootBundle 在 flutter test 下可以讀到 pubspec 宣告的 assets
    TestWidgetsFlutterBinding.ensureInitialized();

    test('assets/config/mishear_rules.json 可以正常解析', () async {
      final config = await MishearRepository().load();

      expect(config.rules.map((r) => r.id), containsAll(['clean', 'lottery']));
      expect(config.fallback.id, 'confused');

      // 規格要求：每個情境至少 3 句台詞，避免重複感
      for (final rule in [...config.rules, config.fallback]) {
        expect(rule.lines.length, greaterThanOrEqualTo(3),
            reason: '${rule.id} 的台詞不足 3 句');
      }
    });
  });
}
