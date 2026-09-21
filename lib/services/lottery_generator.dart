import 'dart:math';

/// 一組「明牌」號碼。
///
/// ⚠️ 純娛樂：號碼由裝置端的偽亂數產生，與任何真實彩券開獎無關，
///    也不做任何預測。UI 上必須顯示對應聲明（見 LotteryCard）。
class LotteryDraw {
  /// 6 個不重複號碼，已由小到大排序
  final List<int> numbers;

  /// 特別號
  final int special;

  const LotteryDraw({required this.numbers, required this.special});
}

class LotteryGenerator {
  LotteryGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// 號碼範圍 1 ~ 49（大樂透格式，僅為了畫面好看，非任何彩種的預測）
  static const int _maxNumber = 49;
  static const int _pickCount = 6;

  LotteryDraw draw() {
    final pool = <int>{};
    while (pool.length < _pickCount) {
      pool.add(_random.nextInt(_maxNumber) + 1);
    }
    final numbers = pool.toList()..sort();

    // 特別號不與前面 6 個重複
    int special;
    do {
      special = _random.nextInt(_maxNumber) + 1;
    } while (numbers.contains(special));

    return LotteryDraw(numbers: numbers, special: special);
  }
}
