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

  /// 語系比對：zh-TW / zh_TW / cmn-Hant-TW 都要視為同一件事，
  /// 所以拿掉分隔符號後比前綴。
  static String _key(String locale) =>
      locale.toLowerCase().replaceAll(RegExp(r'[-_]'), '');

  static bool _match(List<String> list, String locale) {
    final target = _key(locale);
    return list.any((l) {
      final k = _key(l);
      return k == target || k.startsWith(target) || target.startsWith(k);
    });
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
  Stream<ModelDownloadEvent> get downloadEvents => _events
      .receiveBroadcastStream()
      .map((e) => ModelDownloadEvent.fromMap(e as Map<Object?, Object?>));

  Future<SpeechModelSupport> check(String locale) async {
    try {
      final raw = await _method.invokeMethod<Map<Object?, Object?>>(
        'check',
        {'locale': locale},
      );
      if (raw == null) return SpeechModelSupport.unknown;
      return SpeechModelSupport.fromMap(raw);
    } on PlatformException {
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
