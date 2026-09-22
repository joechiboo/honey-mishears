import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 語言包在這台裝置上的狀況
class SpeechModelSupport {
  const SpeechModelSupport({
    required this.apiLevel,
    required this.apiAvailable,
    required this.onDeviceAvailable,
    required this.installed,
    required this.pending,
    required this.supported,
    required this.online,
    this.errorCode,
  });

  /// 裝置的 Android API 版本
  final int apiLevel;

  /// 有沒有 checkRecognitionSupport / triggerModelDownload（Android 13 / API 33 以上）
  final bool apiAvailable;

  /// 這台裝置有沒有裝置端辨識器
  final bool onDeviceAvailable;

  /// 已經可以直接用的語言
  final List<String> installed;

  /// 正在下載中的語言
  final List<String> pending;

  /// 可以下載的語言（**不含**已安裝的）
  final List<String> supported;

  /// 只能連網辨識的語言
  final List<String> online;

  /// checkRecognitionSupport 自己失敗時的錯誤碼
  final int? errorCode;

  static const SpeechModelSupport unknown = SpeechModelSupport(
    apiLevel: 0,
    apiAvailable: false,
    onDeviceAvailable: false,
    installed: [],
    pending: [],
    supported: [],
    online: [],
  );

  /// 語系比對。
  ///
  /// ⚠️ 這裡踩過坑：裝置把台灣中文叫做 **cmn-Hant-TW**，而 speech_to_text
  /// 回報的是 **zh_TW**。原本用「去掉符號後比前綴」的偷懶寫法，
  /// zhtw 對不上 cmnhanttw，於是把「可以下載」誤判成「不支援中文」，
  /// UI 還很有自信地把這個錯誤結論告訴使用者。
  ///
  /// 正解是拆成 語言/文字/地區 三段比：zh 與 cmn 是同一個語言的兩種寫法，
  /// 缺的那一段（例如 zh_TW 沒有寫 Hant）視為通配，不能當成不相等。
  static _LocaleKey _parse(String tag) {
    final parts = tag.toLowerCase().replaceAll('_', '-').split('-')
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return const _LocaleKey('', null, null);

    // zh 與 cmn（Mandarin）指的是同一個語言
    var lang = parts.first;
    if (lang == 'zh') lang = 'cmn';

    String? script;
    String? region;
    for (final part in parts.skip(1)) {
      if (part.length == 4) {
        script = part; // hant / hans
      } else if (part.length == 2 || part.length == 3) {
        region = part; // tw / cn / us
      }
    }
    return _LocaleKey(lang, script, region);
  }

  static bool _sameLocale(String a, String b) {
    final x = _parse(a);
    final y = _parse(b);
    if (x.lang != y.lang) return false;
    // 任一方沒寫的段落視為通配
    if (x.region != null && y.region != null && x.region != y.region) {
      return false;
    }
    if (x.script != null && y.script != null && x.script != y.script) {
      return false;
    }
    return true;
  }

  static bool _match(List<String> list, String locale) =>
      list.any((l) => _sameLocale(l, locale));

  /// 回傳裝置自己用的那個寫法（例如給 zh_TW 會拿到 cmn-Hant-TW）。
  /// 下載與辨識都要用裝置的寫法，不要用我們以為的寫法。
  String? deviceTagFor(String locale) {
    for (final list in [installed, pending, supported]) {
      for (final tag in list) {
        if (_sameLocale(tag, locale)) return tag;
      }
    }
    return null;
  }

  bool isInstalled(String locale) => _match(installed, locale);
  bool isPending(String locale) => _match(pending, locale);

  /// 可以叫系統下載（在可下載清單裡，而且還沒裝好）
  bool canDownload(String locale) =>
      _match(supported, locale) && !isInstalled(locale);

  /// 這台裝置的裝置端辨識根本不支援這個語言——下載也救不了
  bool isHopeless(String locale) =>
      apiAvailable &&
      onDeviceAvailable &&
      errorCode == null &&
      !isInstalled(locale) &&
      !isPending(locale) &&
      !_match(supported, locale);

  factory SpeechModelSupport.fromMap(Map<Object?, Object?> map) {
    List<String> list(String key) =>
        (map[key] as List<Object?>? ?? const []).map((e) => e.toString()).toList();

    return SpeechModelSupport(
      apiLevel: (map['apiLevel'] as num?)?.toInt() ?? 0,
      apiAvailable: map['apiAvailable'] == true,
      onDeviceAvailable: map['onDeviceAvailable'] == true,
      installed: list('installed'),
      pending: list('pending'),
      supported: list('supported'),
      online: list('online'),
      errorCode: (map['errorCode'] as num?)?.toInt(),
    );
  }
}

/// 語系的三段結構：語言 / 文字 / 地區
class _LocaleKey {
  const _LocaleKey(this.lang, this.script, this.region);
  final String lang;
  final String? script;
  final String? region;
}

/// 下載過程回報的事件
enum ModelDownloadStage { scheduled, progress, success, error, unknown }

class ModelDownloadEvent {
  const ModelDownloadEvent(this.stage, {this.percent, this.code});

  final ModelDownloadStage stage;

  /// 0~100；只有 Android 14 (API 34) 以上才會回報
  final int? percent;

  /// 失敗時的錯誤碼
  final int? code;

  factory ModelDownloadEvent.fromMap(Map<Object?, Object?> map) {
    final stage = switch (map['event']) {
      'scheduled' => ModelDownloadStage.scheduled,
      'progress' => ModelDownloadStage.progress,
      'success' => ModelDownloadStage.success,
      'error' => ModelDownloadStage.error,
      _ => ModelDownloadStage.unknown,
    };
    return ModelDownloadEvent(
      stage,
      percent: (map['percent'] as num?)?.toInt(),
      code: (map['code'] as num?)?.toInt(),
    );
  }
}

/// 語言包的查詢與下載。對應 android/.../SpeechModelBridge.kt
class SpeechModelService {
  static const MethodChannel _method =
      MethodChannel('honey_mishears/speech_model');
  static const EventChannel _events =
      EventChannel('honey_mishears/speech_model_events');

  /// 下載進度事件流
  Stream<ModelDownloadEvent> get downloadEvents =>
      _events.receiveBroadcastStream().map((e) {
        debugPrint('[LangPack] event $e');
        return ModelDownloadEvent.fromMap(e as Map<Object?, Object?>);
      });

  Future<SpeechModelSupport> check(String locale) async {
    try {
      // 這支 API 的 callback 有可能不回來，加逾時避免 UI 卡在「檢查中」
      final raw = await _method
          .invokeMethod<Map<Object?, Object?>>('check', {'locale': locale})
          .timeout(const Duration(seconds: 8));

      // 查這類問題時，裝置回報的原始清單比任何推測都有用，直接印出來
      debugPrint('[LangPack] check($locale) -> $raw');

      if (raw == null) return SpeechModelSupport.unknown;
      return SpeechModelSupport.fromMap(raw);
    } on TimeoutException {
      debugPrint('[LangPack] check($locale) 逾時，callback 沒回來');
      return SpeechModelSupport.unknown;
    } on PlatformException catch (e) {
      debugPrint('[LangPack] check($locale) 失敗：$e');
      return SpeechModelSupport.unknown;
    } on MissingPluginException {
      // 非 Android 平台
      return SpeechModelSupport.unknown;
    }
  }

  /// 排程下載。回傳 false 代表這台裝置沒有這個能力，要改走設定頁。
  Future<bool> download(String locale) async {
    try {
      final raw = await _method.invokeMethod<Map<Object?, Object?>>(
        'download',
        {'locale': locale},
      );
      debugPrint('[LangPack] download($locale) -> $raw');
      return raw?['scheduled'] == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 退路：幫使用者打開系統的語音輸入設定頁
  Future<bool> openVoiceInputSettings() async {
    try {
      return await _method.invokeMethod<bool>('openVoiceInputSettings') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
