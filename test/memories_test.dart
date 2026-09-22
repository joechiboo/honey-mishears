import 'package:flutter_test/flutter_test.dart';
import 'package:honey_mishears/data/memories.dart';
import 'package:honey_mishears/data/wife_identity.dart';

void main() {
  group('記住發生過的事', () {
    test('第一次會多一則', () {
      final after = Memories.empty.remember(MemoryId.rule('clean'));
      expect(after.has(MemoryId.rule('clean')), isTrue);
      expect(after.count, 1);
    });

    test('沒發生過的還是沒發生', () {
      final after = Memories.empty.remember(MemoryId.rule('clean'));
      expect(after.has(MemoryId.rule('lottery')), isFalse);
    });

    test('原本的集合不會被改動', () {
      const before = Memories.empty;
      before.remember(MemoryId.rule('clean'));
      expect(before.count, 0);
    });

    // home_page 用 identical() 判斷「這是不是第一次」，再決定要不要寫檔；
    // 回傳新物件就會每輪都白寫一次 SharedPreferences。
    test('重複記同一則會回傳自己', () {
      final once = Memories.empty.remember(MemoryId.rule('clean'));
      final twice = once.remember(MemoryId.rule('clean'));
      expect(identical(once, twice), isTrue);
    });

    test('記不同的兩則會回傳新物件', () {
      final once = Memories.empty.remember(MemoryId.rule('clean'));
      final twice = once.remember(MemoryId.rule('lottery'));
      expect(identical(once, twice), isFalse);
      expect(twice.count, 2);
    });
  });

  group('回憶 id', () {
    // 不同來源的回憶共用同一份儲存，所以前綴不能撞。
    // 而且前綴一旦寫進使用者手機就不能改——改了等於清掉人家的回憶。
    test('梗與里程碑不會互相誤認', () {
      expect(MemoryId.rule('naming'), isNot(MemoryId.naming));
    });

    test('梗的 id 帶得出規則名', () {
      expect(MemoryId.rule('clean'), 'rule:clean');
    });
  });

  group('取名那一則', () {
    test('取了名字就把名字寫在上面', () {
      const identity = WifeIdentity(name: '小咪');
      expect(namingMemoryEntry(identity).detail, contains('小咪'));
    });

    // 還沒取名時這一則是「還沒發生」，顯示的是 hint——所以 hint 不能空著，
    // 而且要指得到路：問她，或長按標題。
    test('還沒取名時留一句指得到路的話', () {
      final entry = namingMemoryEntry(WifeIdentity.empty);
      expect(entry.hint, isNotEmpty);
      expect(entry.id, MemoryId.naming);
    });
  });
}
