import 'package:flutter_test/flutter_test.dart';
import 'package:honey_mishears/core/app_config.dart';
import 'package:honey_mishears/data/wife_identity.dart';

void main() {
  group('名字代入台詞', () {
    test('沒取名時 {name} 變成「我」', () {
      expect(
        WifeIdentity.empty.personalize('交給{name}，你去旁邊坐著就好。'),
        '交給我，你去旁邊坐著就好。',
      );
    });

    test('取了名字就代入名字，一句裡出現幾次都換', () {
      const identity = WifeIdentity(name: '小咪');
      expect(identity.personalize('{name}、{name}——好。'), '小咪、小咪——好。');
    });

    test('沒有 {name} 的台詞原樣不動', () {
      expect(WifeIdentity.empty.personalize('嗯？'), '嗯？');
    });
  });

  group('標題顯示', () {
    test('沒取名時沿用 App 名稱', () {
      expect(WifeIdentity.empty.displayName, AppConfig.appName);
      expect(WifeIdentity.empty.hasName, isFalse);
    });

    test('取了名字就顯示名字', () {
      expect(const WifeIdentity(name: '小咪').displayName, '小咪');
    });

    test('空字串當作沒取名', () {
      expect(const WifeIdentity(name: '').hasName, isFalse);
    });
  });

  group('她該不該主動開口要名字', () {
    test('互動次數還沒到門檻就不問', () {
      const identity = WifeIdentity(interactions: AppConfig.namingPromptAfter - 1);
      expect(identity.shouldOfferNaming, isFalse);
    });

    test('到了門檻才問', () {
      const identity = WifeIdentity(interactions: AppConfig.namingPromptAfter);
      expect(identity.shouldOfferNaming, isTrue);
    });

    test('已經有名字就永遠不問', () {
      const identity = WifeIdentity(name: '小咪', interactions: 999);
      expect(identity.shouldOfferNaming, isFalse);
    });

    test('被打發一次之後，門檻往後推，不會下一輪又問', () {
      const justDeclined = WifeIdentity(
        interactions: AppConfig.namingPromptAfter,
        promptDeclines: 1,
      );
      expect(justDeclined.shouldOfferNaming, isFalse);

      const later = WifeIdentity(
        interactions: AppConfig.namingPromptAfter + AppConfig.namingPromptCooldown,
        promptDeclines: 1,
      );
      expect(later.shouldOfferNaming, isTrue);
    });

    test('打發滿次數之後就永久不再主動問', () {
      const identity = WifeIdentity(
        interactions: 100000,
        promptDeclines: AppConfig.maxNamingPromptDeclines,
      );
      expect(identity.shouldOfferNaming, isFalse);
    });
  });

  group('copyWith', () {
    test('clearName 可以把名字拿掉', () {
      const identity = WifeIdentity(name: '小咪', interactions: 3);
      final cleared = identity.copyWith(clearName: true);
      expect(cleared.hasName, isFalse);
      expect(cleared.interactions, 3);
    });
  });
}
