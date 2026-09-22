import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/telemetry_config.dart';
import '../data/telemetry_store.dart';
import '../data/transcript_record.dart';

/// 把一批紀錄送出去。回傳 true 代表確定送達（可以從佇列移除）。
typedef RowSender = Future<bool> Function(List<Map<String, dynamic>> rows);

/// 逐字稿回傳。
///
/// 三條規則，順序就是程式碼的順序：
/// 1. **不擋流程**：record() 不 await 網路，失敗只留在佇列裡，永不往 UI 丟例外。
///    她該立刻開始掃地，不能為了回報等一個 HTTP。
/// 2. **關了就不留**：同意關閉時連佇列一起清（見 [TelemetryStore.setEnabled]）。
/// 3. **不確定就別刪**：送不成功的批次留在佇列，下次再試。
class TranscriptUploader {
  TranscriptUploader({
    required this.store,
    RowSender? sender,
  }) : _send = sender ?? _postToSupabase;

  final TelemetryStore store;
  final RowSender _send;

  bool _flushing = false;

  /// 現在到底會不會送。UI 要顯示狀態時問這個。
  bool get active => TelemetryConfig.configured && store.enabled;

  /// 記一筆，並順手試著把佇列送出去。
  ///
  /// 沒設定端點時**連佇列都不寫**——不留一堆永遠送不出去的資料在使用者手機上。
  Future<void> record({
    required String transcript,
    required bool matched,
    String? ruleId,
  }) async {
    if (!active) return;
    final text = transcript.trim();
    if (text.isEmpty) return;

    final queue = [
      ...store.queued,
      TranscriptRecord(
        transcript: text,
        matched: matched,
        ruleId: ruleId,
        at: DateTime.now(),
      ),
    ];

    // 超過上限丟最舊的
    final trimmed = queue.length > TelemetryConfig.maxQueued
        ? queue.sublist(queue.length - TelemetryConfig.maxQueued)
        : queue;

    await store.setQueued(trimmed);
    await flush();
  }

  /// 把佇列前面 [TelemetryConfig.batchSize] 筆送出去。
  ///
  /// 同時只跑一次：record() 每輪都會呼叫，重入會讓同一批送兩次。
  Future<void> flush() async {
    if (!active || _flushing) return;

    final pending = store.queued;
    if (pending.isEmpty) return;

    _flushing = true;
    try {
      final batch = pending.take(TelemetryConfig.batchSize).toList();
      final rows = batch
          .map((r) => r.toRow(
                deviceId: store.deviceId,
                appVersion: TelemetryConfig.appVersion,
              ))
          .toList();

      final ok = await _send(rows);
      if (!ok) return; // 留著，下次再試

      // 重讀一次而不是用 pending：flush 期間可能又進了新的一筆
      final now = store.queued;
      await store.setQueued(now.sublist(batch.length.clamp(0, now.length)));
    } catch (error) {
      // 回報失敗永遠不該影響使用者。記一行 log 就好。
      debugPrint('[Telemetry] 送出失敗：$error');
    } finally {
      _flushing = false;
    }
  }

  static Future<bool> _postToSupabase(List<Map<String, dynamic>> rows) async {
    final response = await http.post(
      TelemetryConfig.insertEndpoint,
      headers: {
        'apikey': TelemetryConfig.supabaseAnonKey,
        'Authorization': 'Bearer ${TelemetryConfig.supabaseAnonKey}',
        'Content-Type': 'application/json',
        // 不用回傳寫進去的內容，省一趟 payload
        'Prefer': 'return=minimal',
      },
      body: jsonEncode(rows),
    );

    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (!ok) {
      debugPrint('[Telemetry] Supabase 回 ${response.statusCode}：${response.body}');
    }
    return ok;
  }
}
