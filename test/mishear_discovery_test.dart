import 'package:flutter_test/flutter_test.dart';
import 'package:honey_mishears/data/mishear_discovery.dart';

void main() {
  group('解鎖', () {
    test('第一次發現會多一筆', () {
      final after = MishearDiscovery.empty.unlock('clean');
      expect(after.has('clean'), isTrue);
      expect(after.count, 1);
    });

    test('沒發現過的仍然蓋著', () {
      final after = MishearDiscovery.empty.unlock('clean');
      expect(after.has('lottery'), isFalse);
    });

    test('原本的集合不會被改動', () {
      const before = MishearDiscovery.empty;
      before.unlock('clean');
      expect(before.count, 0);
    });

    // home_page 用 identical() 判斷「這輪是不是第一次發現」，
    // 再決定要不要寫檔；回傳新物件就會每輪都白寫一次 SharedPreferences。
    test('重複解鎖同一筆會回傳自己', () {
      final once = MishearDiscovery.empty.unlock('clean');
      final twice = once.unlock('clean');
      expect(identical(once, twice), isTrue);
    });

    test('解鎖不同筆會回傳新物件', () {
      final once = MishearDiscovery.empty.unlock('clean');
      final twice = once.unlock('lottery');
      expect(identical(once, twice), isFalse);
      expect(twice.count, 2);
    });
  });
}
