import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import '../core/app_config.dart';
import 'speech_model_service.dart';

/// 麥克風權限狀態（簡化成 UI 真正需要分辨的幾種）
enum MicPermission {
  /// 已授權
  granted,

  /// 這次被拒絕，還可以再問一次
  denied,

  /// 使用者勾了「不要再問」，只能引導去系統設定
  permanentlyDenied,
}

/// 語音辨識封裝：把 speech_to_text 與權限處理包在一起，
/// UI 只需要 requestPermission / start / stop 三個動作。
class SpeechService {
  final SpeechToText _speech = SpeechToText();
  final SpeechModelService _models = SpeechModelService();

  bool _initialized = false;
  String? _localeId;
  List<String> _availableLocales = const [];

  /// 預先查好的裝置語系寫法。在 App 啟動時先問（不需要麥克風權限），
  /// 這樣第一次按下說話鈕時就不必等這一段。
  String? _prewarmedTag;
  String? _lastError;

  bool get isInitialized => _initialized;
  bool get isListening => _speech.isListening;

  /// 目前使用的辨識語系（除錯用）
  String? get localeId => _localeId;

  /// 這台裝置的辨識服務回報支援的語系清單（診斷畫面用）
  List<String> get availableLocales => _availableLocales;

  /// 最後一次辨識錯誤代碼，例如 error_language_unavailable
  String? get lastError => _lastError;

  /// 啟動時的暖機：先問辨識器它怎麼稱呼中文。
  ///
  /// checkRecognitionSupport 不需要麥克風權限，所以可以在還沒要權限前就做。
  /// 這一段本來夾在「按下說話鈕」之後，害第一次按要等一兩秒才真正開始收音，
  /// 使用者往往在那之前就放開手了。
  Future<void> prewarm() async {
    final support = await _models.check(AppConfig.preferredLocale);
    if (support.isInstalled(AppConfig.preferredLocale)) {
      _prewarmedTag = support.deviceTagFor(AppConfig.preferredLocale);
    }
  }

  /// 要求麥克風權限。
  /// 注意：Android 上如果使用者已經永久拒絕，request() 會直接回 permanentlyDenied，
  ///       系統不會再跳出對話框，所以要由我們引導去設定頁。
  Future<MicPermission> requestPermission() async {
    var status = await Permission.microphone.status;

    if (status.isGranted) return MicPermission.granted;
    if (status.isPermanentlyDenied) return MicPermission.permanentlyDenied;

    status = await Permission.microphone.request();

    if (status.isGranted) return MicPermission.granted;
    if (status.isPermanentlyDenied) return MicPermission.permanentlyDenied;
    return MicPermission.denied;
  }

  /// 打開系統的 App 設定頁，讓使用者手動開麥克風
  Future<bool> openSettings() => openAppSettings();

  /// 初始化辨識引擎。回傳 false 代表這台裝置沒有可用的語音辨識服務。
  Future<bool> initialize({
    ValueChanged<String>? onStatus,
    ValueChanged<String>? onError,
  }) async {
    if (_initialized) return true;

    _initialized = await _speech.initialize(
      onStatus: (status) => onStatus?.call(status),
      onError: (error) {
        _lastError = error.errorMsg;
        onError?.call(error.errorMsg);
      },
      debugLogging: kDebugMode,
    );

    if (_initialized) {
      _localeId = await _resolveLocaleId();
      debugPrint('[STT] 送給辨識器的語系 = $_localeId');
    }
    return _initialized;
  }

  /// 挑辨識語系。
  ///
  /// ⚠️ 這裡踩過兩個坑，順序不能顛倒：
  ///
  /// 1. speech_to_text 回報的寫法是 `zh_TW`（底線），但 Android 的裝置端辨識器
  ///    自己把台灣中文叫 `cmn-Hant-TW`。送 `zh_TW` 進去它解析不了，會**安靜地**
  ///    退回預設語系 en-US，然後因為 en-US 的語言包沒裝而報
  ///    LANGUAGE_PACK_ERROR——錯誤訊息完全指不到真正的原因。
  /// 2. 所以語系寫法要以**辨識器自己的已安裝模型清單**為準，
  ///    speech_to_text 的清單只能當退路。
  Future<String?> _resolveLocaleId() async {
    // 暖機時已經問過就直接用，省掉一次跨平台呼叫
    if (_prewarmedTag != null) return _prewarmedTag;

    // 第一順位：辨識器已經裝好的中文模型，用它自己的寫法
    final support = await _models.check(AppConfig.preferredLocale);
    final installedTag = support.deviceTagFor(AppConfig.preferredLocale);
    if (installedTag != null && support.isInstalled(AppConfig.preferredLocale)) {
      return installedTag;
    }

    // 退路：從 speech_to_text 的清單挑，並把底線換成連字號
    try {
      final locales = await _speech.locales();
      _availableLocales = locales.map((l) => l.localeId).toList();

      String? firstWhere(bool Function(String id) test) {
        for (final locale in locales) {
          if (test(locale.localeId.toLowerCase().replaceAll('-', '_'))) {
            return locale.localeId.replaceAll('_', '-');
          }
        }
        return null;
      }

      return firstWhere((id) => id == 'zh_tw' || id == 'cmn_hant_tw') ??
          firstWhere((id) => id.contains('tw') || id.contains('hant')) ??
          firstWhere((id) => id.startsWith('zh') || id.startsWith('cmn'));
    } catch (_) {
      return null;
    }
  }

  /// 開始收音。[onResult] 會被呼叫多次（逐字結果），isFinal=true 是最終結果。
  Future<void> start({
    required void Function(String text, bool isFinal) onResult,
    ValueChanged<double>? onSoundLevel,
  }) async {
    if (!_initialized) return;
    _lastError = null;

    // 查詢／下載語言包用的是裝置端辨識器，是獨占資源。
    // 沒放乾淨就 listen，會拿到 ERROR_RECOGNIZER_BUSY。
    await _models.release();

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      onSoundLevelChange: onSoundLevel == null
          ? null
          : (level) => onSoundLevel(level),
      localeId: _localeId,
      listenFor: AppConfig.maxListenDuration,
      pauseFor: AppConfig.pauseDuration,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        onDevice: AppConfig.forceOnDeviceRecognition,
      ),
    );
  }

  /// 正常結束收音（會送出最終結果）
  Future<void> stop() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  /// 直接取消（不會有最終結果）
  Future<void> cancel() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }
}
