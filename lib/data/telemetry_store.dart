import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'transcript_record.dart';

/// 回傳設定與待送佇列的存放處。
///
/// 抽成介面是為了讓上傳邏輯（佇列上限、批次、失敗保留）能在沒有
/// SharedPreferences、也沒有網路的情況下測得到——那些規則才是容易寫錯的部分。
abstract class TelemetryStore {
  bool get enabled;
  Future<void> setEnabled(bool value);

  /// 首次啟動的告知面板有沒有出現過
  bool get noticeShown;
  Future<void> markNoticeShown();

  /// 本機產生的隨機識別碼。**不是** Android ID，可以重設。
  String get deviceId;
  Future<void> resetDeviceId();

  List<TranscriptRecord> get queued;
  Future<void> setQueued(List<TranscriptRecord> records);
}

class SharedPrefsTelemetryStore implements TelemetryStore {
  SharedPrefsTelemetryStore(this._prefs);

  final SharedPreferences _prefs;

  static const _kEnabled = 'telemetry.enabled';
  static const _kNotice = 'telemetry.noticeShown';
  static const _kDeviceId = 'telemetry.deviceId';
  static const _kQueue = 'telemetry.queue';

  static Future<SharedPrefsTelemetryStore> open() async =>
      SharedPrefsTelemetryStore(await SharedPreferences.getInstance());

  /// 預設開。使用者可以在設定面板關掉，關掉就連本機佇列一起清空。
  @override
  bool get enabled => _prefs.getBool(_kEnabled) ?? true;

  @override
  Future<void> setEnabled(bool value) async {
    await _prefs.setBool(_kEnabled, value);
    // 關掉的時候把還沒送出去的一起丟掉。留著等下次開啟才送，
    // 等於沒有真的尊重那個關閉動作。
    if (!value) await _prefs.remove(_kQueue);
  }

  @override
  bool get noticeShown => _prefs.getBool(_kNotice) ?? false;

  @override
  Future<void> markNoticeShown() => _prefs.setBool(_kNotice, true);

  @override
  String get deviceId {
    final existing = _prefs.getString(_kDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final fresh = _newDeviceId();
    // 同步 getter 不能 await；先寫回去，失敗了下次啟動再產一個就好
    _prefs.setString(_kDeviceId, fresh);
    return fresh;
  }

  @override
  Future<void> resetDeviceId() => _prefs.setString(_kDeviceId, _newDeviceId());

  @override
  List<TranscriptRecord> get queued {
    final raw = _prefs.getString(_kQueue);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => TranscriptRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // 格式壞了就當作沒有。這是可丟的資料，不值得為它讓 App 掛掉。
      return const [];
    }
  }

  @override
  Future<void> setQueued(List<TranscriptRecord> records) async {
    if (records.isEmpty) {
      await _prefs.remove(_kQueue);
      return;
    }
    await _prefs.setString(
      _kQueue,
      jsonEncode(records.map((r) => r.toJson()).toList()),
    );
  }

  /// UUID v4。為了不多一個套件，自己用 Random.secure 湊。
  static String _newDeviceId() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
