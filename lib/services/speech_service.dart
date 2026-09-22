import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import '../core/app_config.dart';

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

  bool _initialized = false;
  String? _localeId;
  List<String> _availableLocales = const [];
  String? _lastError;

  bool get isInitialized => _initialized;
  bool get isListening => _speech.isListening;

  /// 目前使用的辨識語系（除錯用）
  String? get localeId => _localeId;

  /// 這台裝置的辨識服務回報支援的語系清單（診斷畫面用）
  List<String> get availableLocales => _availableLocales;

  /// 最後一次辨識錯誤代碼，例如 error_language_unavailable
  String? get lastError => _lastError;

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
    }
    return _initialized;
  }

  /// 挑辨識語系。
  ///
  /// 原本寫「取第一個 zh 開頭的」會誤中 zh-CN；改成依偏好順序精準挑：
  /// 台灣中文 → 任何繁中 → 任何中文 → 交給系統預設（null）。
  Future<String?> _resolveLocaleId() async {
    try {
      final locales = await _speech.locales();
      _availableLocales = locales.map((l) => l.localeId).toList();

      String? firstWhere(bool Function(String id) test) {
        for (final locale in locales) {
          if (test(locale.localeId.toLowerCase().replaceAll('-', '_'))) {
            return locale.localeId;
          }
        }
        return null;
      }

      return firstWhere((id) => id == 'zh_tw' || id == 'cmn_hant_tw') ??
          firstWhere((id) => id.contains('tw') || id.contains('hant')) ??
          firstWhere((id) => id.startsWith('zh') || id.startsWith('cmn'));
    } catch (_) {
      // 某些裝置查詢語系會失敗，交給系統預設
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
