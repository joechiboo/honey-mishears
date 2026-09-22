import 'package:flutter_test/flutter_test.dart';
import 'package:honey_mishears/services/speech_model_service.dart';

/// 這台 S23 實際回報的清單（2026-09-22 實測），拿來當測試資料
SpeechModelSupport _s23() => const SpeechModelSupport(
      apiLevel: 36,
      apiAvailable: true,
      onDeviceAvailable: true,
      installed: [],
      pending: [],
      supported: [
        'en-US', 'de-DE', 'es-ES', 'fr-FR', 'it-IT', 'ja-JP', 'ko-KR',
        'cmn-Hans-CN', 'cmn-Hant-TW', 'vi-VN',
      ],
      online: [],
    );

void main() {
  group('語系比對（zh_TW ↔ cmn-Hant-TW）', () {
    // 這組測試對應一個實際發生過的 bug：
    // 原本用「去掉符號比前綴」，zhtw 對不上 cmnhanttw，
    // 於是把「可以下載」誤判成「不支援中文」，UI 還把錯誤結論講給使用者聽。
    final support = _s23();

    test('zh_TW 要認得出裝置寫的 cmn-Hant-TW', () {
      expect(support.canDownload('zh_TW'), isTrue);
      expect(support.isHopeless('zh_TW'), isFalse);
      expect(support.deviceTagFor('zh_TW'), 'cmn-Hant-TW');
    });

    test('zh-TW、zh-Hant-TW 等寫法都要一致', () {
      for (final tag in ['zh-TW', 'zh_TW', 'zh-Hant-TW', 'cmn-Hant-TW']) {
        expect(support.canDownload(tag), isTrue, reason: tag);
        expect(support.deviceTagFor(tag), 'cmn-Hant-TW', reason: tag);
      }
    });

    test('不可以誤中簡體中文', () {
      expect(support.deviceTagFor('zh_CN'), 'cmn-Hans-CN');
      expect(support.deviceTagFor('zh_TW'), isNot('cmn-Hans-CN'));
    });

    test('沒寫地區的 zh 視為通配，會挑到清單裡第一個中文', () {
      expect(support.canDownload('zh'), isTrue);
    });

    test('真的沒有的語言要老實說不支援', () {
      expect(support.canDownload('ar-SA'), isFalse);
      expect(support.isHopeless('ar-SA'), isTrue);
    });

    test('已安裝的語言不算「可下載」', () {
      const installed = SpeechModelSupport(
        apiLevel: 36,
        apiAvailable: true,
        onDeviceAvailable: true,
        installed: ['cmn-Hant-TW'],
        pending: [],
        supported: ['cmn-Hant-TW', 'en-US'],
        online: [],
      );
      expect(installed.isInstalled('zh_TW'), isTrue);
      expect(installed.canDownload('zh_TW'), isFalse);
    });
  });
}
