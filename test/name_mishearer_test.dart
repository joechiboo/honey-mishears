import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:honey_mishears/core/app_config.dart';
import 'package:honey_mishears/data/mishear_repository.dart';
import 'package:honey_mishears/data/naming_config.dart';
import 'package:honey_mishears/services/name_mishearer.dart';

/// 測試用的假設定，不依賴真正的 JSON
const NamingConfig _naming = NamingConfig(
  keywords: ['你叫什麼名字'],
  strip: ['我想叫你', '就叫你', '叫你', '好不好', '以後'],
  substitutions: {
    '美': ['咪'],
    '妮': ['泥'],
  },
);

NameMishearer _mishearer([int seed = 1]) =>
    NameMishearer(_naming, random: Random(seed));

void main() {
  group('把辨識結果整理成名字', () {
    test('只講名字本身就原樣留下', () {
      expect(_mishearer().sanitize('小美'), '小美');
    });

    test('前後的贅詞會被剝掉', () {
      expect(_mishearer().sanitize('就叫你小美好不好'), '小美');
      expect(_mishearer().sanitize('我想叫你小美'), '小美');
      expect(_mishearer().sanitize('以後叫你小美'), '小美');
    });

    test('長的贅詞先剝，不會被短的咬掉一半', () {
      // 「就叫」若先被剝掉會留下「你小美」
      expect(_mishearer().sanitize('就叫你小美'), '小美');
    });

    test('標點與空白會被去掉', () {
      expect(_mishearer().sanitize('小　美！'), '小美');
    });

    test('辨識不到內容時回 null，讓流程轉去打字', () {
      expect(_mishearer().sanitize(''), isNull);
      expect(_mishearer().sanitize('？？！'), isNull);
    });

    test('整段話進來時會截斷', () {
      final name = _mishearer().sanitize('一二三四五六七八九十');
      expect(name, isNotNull);
      expect(name!.runes.length, AppConfig.maxWifeNameLength);
    });

    test('剝完只剩贅詞本身時不會把名字剝成空字串', () {
      // 使用者只說了「叫你」，沒有真的給名字
      expect(_mishearer().sanitize('叫你'), '叫你');
    });
  });

  group('她聽錯名字', () {
    test('換字表裡的字會被換掉', () {
      expect(_mishearer().mishear('小美'), '小咪');
      expect(_mishearer().mishear('妮妮'), anyOf('泥妮', '妮泥'));
    });

    test('換字表對不上時回 null（她剛好聽對了）', () {
      expect(_mishearer().mishear('阿強'), isNull);
    });

    test('聽錯的結果一定跟原本的名字不一樣', () {
      for (var seed = 0; seed < 20; seed++) {
        final result = NameMishearer(_naming, random: Random(seed)).mishear('小美妮');
        expect(result, isNotNull);
        expect(result, isNot('小美妮'));
      }
    });
  });

  group('實際的設定檔', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('naming 區塊解析得出來，而且內容夠用', () async {
      final config = await MishearRepository().load();
      final naming = config.naming;

      expect(naming.keywords, isNotEmpty);
      expect(naming.substitutions, isNotEmpty);
      expect(naming.strip, isNotEmpty);

      // 跟諧音梗一樣的規格：每個情境至少 3 句台詞
      expect(naming.offer.length, greaterThanOrEqualTo(3));
      expect(naming.prompt.length, greaterThanOrEqualTo(3));
      expect(naming.unheard.length, greaterThanOrEqualTo(3));
      expect(naming.accepted.length, greaterThanOrEqualTo(3));

      // accepted 是唯一一定要帶到名字的台詞池
      for (final line in naming.accepted) {
        expect(line, contains('{name}'), reason: '取好名字的台詞沒有用到 {name}：$line');
      }

      // 換字表的每個字都要真的換成別的字，否則會端出「你是說 X 嗎」但 X 就是 X
      naming.substitutions.forEach((from, candidates) {
        expect(from.runes.length, 1, reason: '換字表的 key 只能是單一個字：$from');
        expect(candidates, isNotEmpty, reason: '$from 沒有給聽錯的候選字');
        for (final to in candidates) {
          expect(to, isNot(from), reason: '$from 換成自己等於沒聽錯');
        }
      });
    });
  });
}
