import 'package:flutter_test/flutter_test.dart';
import 'package:honey_mishears/services/lottery_generator.dart';

void main() {
  final generator = LotteryGenerator();

  test('每次抽出 6 個不重複、由小到大的號碼', () {
    // 隨機邏輯跑多次才有意義
    for (var i = 0; i < 200; i++) {
      final draw = generator.draw();

      expect(draw.numbers.length, 6);
      expect(draw.numbers.toSet().length, 6, reason: '號碼不可重複');

      final sorted = [...draw.numbers]..sort();
      expect(draw.numbers, sorted, reason: '號碼要由小到大');
    }
  });

  test('號碼與特別號都落在 1~49', () {
    for (var i = 0; i < 200; i++) {
      final draw = generator.draw();
      for (final n in [...draw.numbers, draw.special]) {
        expect(n, inInclusiveRange(1, 49));
      }
    }
  });

  test('特別號不會跟前 6 個號碼重複', () {
    for (var i = 0; i < 200; i++) {
      final draw = generator.draw();
      expect(draw.numbers, isNot(contains(draw.special)));
    }
  });
}
