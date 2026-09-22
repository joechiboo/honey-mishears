import 'package:flutter_test/flutter_test.dart';
import 'package:honey_mishears/core/telemetry_config.dart';
import 'package:honey_mishears/data/telemetry_store.dart';
import 'package:honey_mishears/data/transcript_record.dart';
import 'package:honey_mishears/services/transcript_uploader.dart';

/// 記憶體版的 store，讓佇列規則不必碰 SharedPreferences 就測得到。
class _FakeStore implements TelemetryStore {
  _FakeStore({this.enabled = true});

  @override
  bool enabled;
  @override
  bool noticeShown = false;
  @override
  String deviceId = 'test-device';

  List<TranscriptRecord> _queue = const [];

  @override
  List<TranscriptRecord> get queued => _queue;

  @override
  Future<void> setQueued(List<TranscriptRecord> records) async {
    _queue = List.of(records);
  }

  @override
  Future<void> setEnabled(bool value) async {
    enabled = value;
    if (!value) _queue = const [];
  }

  @override
  Future<void> markNoticeShown() async => noticeShown = true;

  @override
  Future<void> resetDeviceId() async => deviceId = 'reset-device';
}

void main() {
  // 這幾個測試都注入 sender，所以不需要真的端點；但 active 會看
  // TelemetryConfig.configured，測試環境沒有 --dart-define，所以它是 false。
  // 因此驗的是「有注入 sender 時的佇列行為」——用一個不看 configured 的子類。
  TranscriptUploader build(_FakeStore store, RowSender sender) =>
      _TestableUploader(store: store, sender: sender);

  group('回傳佇列', () {
    test('關閉時什麼都不記', () async {
      final store = _FakeStore(enabled: false);
      var calls = 0;
      final uploader = build(store, (rows) async {
        calls++;
        return true;
      });

      await uploader.record(transcript: '親一個', matched: true, ruleId: 'clean');

      expect(store.queued, isEmpty);
      expect(calls, 0);
    });

    test('空白的逐字稿不記', () async {
      final store = _FakeStore();
      final uploader = build(store, (rows) async => true);

      await uploader.record(transcript: '   ', matched: false);

      expect(store.queued, isEmpty);
    });

    test('送成功就從佇列移除', () async {
      final store = _FakeStore();
      final uploader = build(store, (rows) async => true);

      await uploader.record(transcript: '你好', matched: true, ruleId: 'mask');

      expect(store.queued, isEmpty);
    });

    test('送失敗要留著，下次再試', () async {
      final store = _FakeStore();
      var attempts = 0;
      final uploader = build(store, (rows) async {
        attempts++;
        return false;
      });

      await uploader.record(transcript: '在幹嘛', matched: false);
      expect(store.queued, hasLength(1), reason: '送不出去不能丟掉');

      await uploader.record(transcript: '吃飯了', matched: false);
      expect(store.queued, hasLength(2));
      expect(attempts, 2);
    });

    test('超過上限丟最舊的，留最新的', () async {
      final store = _FakeStore();
      // 一直送失敗，佇列才會累積到上限
      final uploader = build(store, (rows) async => false);

      for (var i = 0; i < TelemetryConfig.maxQueued + 5; i++) {
        await uploader.record(transcript: '第$i句', matched: false);
      }

      expect(store.queued, hasLength(TelemetryConfig.maxQueued));
      expect(store.queued.first.transcript, '第5句', reason: '最舊的 5 筆被丟掉');
      expect(store.queued.last.transcript,
          '第${TelemetryConfig.maxQueued + 4}句');
    });

    test('一次最多送 batchSize 筆', () async {
      final store = _FakeStore();
      final sizes = <int>[];
      var succeed = false;
      final uploader = build(store, (rows) async {
        sizes.add(rows.length);
        return succeed;
      });

      for (var i = 0; i < TelemetryConfig.batchSize + 3; i++) {
        await uploader.record(transcript: '第$i句', matched: false);
      }

      succeed = true;
      await uploader.flush();

      expect(sizes.last, TelemetryConfig.batchSize);
      expect(store.queued, hasLength(3), reason: '剩下的留在佇列等下一批');
    });

    test('關閉時連還沒送出的一起清掉', () async {
      final store = _FakeStore();
      final uploader = build(store, (rows) async => false);

      await uploader.record(transcript: '留著', matched: false);
      expect(store.queued, hasLength(1));

      await store.setEnabled(false);
      expect(store.queued, isEmpty, reason: '關閉要連佇列一起刪，不然等於沒關');
    });
  });

  group('送出去的那一列', () {
    test('帶 device_id 與命中結果，不帶其他東西', () {
      final row = TranscriptRecord(
        transcript: '抱緊我',
        matched: true,
        ruleId: 'bundle',
        at: DateTime.utc(2026, 9, 22),
      ).toRow(deviceId: 'dev-1', appVersion: '1.2.3');

      expect(row.keys, containsAll(<String>['device_id', 'transcript',
          'matched', 'matched_rule_id', 'app_version', 'created_at']));
      expect(row.keys, hasLength(6), reason: '欄位只該有這六個——多一個就是多收資料');
      expect(row['transcript'], '抱緊我');
      expect(row['matched_rule_id'], 'bundle');
    });

    test('沒命中時 matched_rule_id 是 null', () {
      final row = TranscriptRecord(
        transcript: '今天天氣真好',
        matched: false,
        at: DateTime.utc(2026, 9, 22),
      ).toRow(deviceId: 'dev-1', appVersion: 'dev');

      expect(row['matched'], isFalse);
      expect(row['matched_rule_id'], isNull);
    });

    test('本機佇列的序列化可以原樣讀回來', () {
      final original = TranscriptRecord(
        transcript: '親一個',
        matched: true,
        ruleId: 'clean',
        at: DateTime.utc(2026, 9, 22, 10, 30),
      );

      final restored = TranscriptRecord.fromJson(original.toJson());

      expect(restored.transcript, original.transcript);
      expect(restored.matched, original.matched);
      expect(restored.ruleId, original.ruleId);
      expect(restored.at.toUtc(), original.at.toUtc());
    });
  });
}

/// 測試用：跳過「端點有沒有設定」這一關。
/// 正式版沒帶 --dart-define 就不該送任何東西，那是刻意的；
/// 但佇列規則本身要測得到，所以這裡只看 store.enabled。
class _TestableUploader extends TranscriptUploader {
  _TestableUploader({required super.store, required RowSender super.sender});

  @override
  bool get active => store.enabled;
}
