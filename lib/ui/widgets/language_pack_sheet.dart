import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/speech_model_service.dart';

/// 語言包引導面板。
///
/// 使用者遇到 error_language_unavailable 時看到的東西。重點是**不要**只丟一句
/// 「請到系統設定下載語言包」——那個路徑埋在三層選單底下，一般人找不到。
/// Android 13 以上可以直接在這裡按一個鍵下載完。
///
/// 回傳 true 代表語言包已經就緒，呼叫端可以叫使用者再試一次。
Future<bool> showLanguagePackSheet(
  BuildContext context, {
  required String locale,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _LanguagePackSheet(locale: locale),
  );
  return result ?? false;
}

enum _Phase { checking, needsDownload, downloading, done, blocked }

class _LanguagePackSheet extends StatefulWidget {
  const _LanguagePackSheet({required this.locale});

  final String locale;

  @override
  State<_LanguagePackSheet> createState() => _LanguagePackSheetState();
}

class _LanguagePackSheetState extends State<_LanguagePackSheet> {
  final SpeechModelService _service = SpeechModelService();

  _Phase _phase = _Phase.checking;
  StreamSubscription<ModelDownloadEvent>? _sub;

  int? _percent;
  String _blockedReason = '';

  /// 裝置自己對這個語言的寫法（例如 cmn-Hant-TW）。
  /// 下載一定要用它，用我們以為的 zh_TW 系統不認得。
  String? _deviceTag;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _sub?.cancel();
    // 面板關掉時，平台層可能還握著查詢/下載用的辨識器
    _service.release();
    super.dispose();
  }

  Future<void> _check() async {
    final support = await _service.check(widget.locale);
    if (!mounted) return;

    setState(() {
      _deviceTag = support.deviceTagFor(widget.locale);

      if (support.isInstalled(widget.locale)) {
        _phase = _Phase.done;
      } else if (support.isPending(widget.locale)) {
        _phase = _Phase.downloading;
      } else if (support.canDownload(widget.locale)) {
        _phase = _Phase.needsDownload;
      } else if (!support.apiAvailable) {
        _phase = _Phase.blocked;
        _blockedReason =
            '你的 Android 版本（API ${support.apiLevel}）沒有「App 內下載語音包」這個能力，'
            '需要手動到系統設定裡下載。';
      } else if (!support.onDeviceAvailable) {
        _phase = _Phase.blocked;
        _blockedReason = '這台裝置沒有可用的離線語音辨識服務。';
      } else if (support.errorCode != null) {
        _phase = _Phase.blocked;
        _blockedReason = '查詢語音包狀態失敗（錯誤碼 ${support.errorCode}）。';
      } else {
        _phase = _Phase.blocked;
        _blockedReason = '這台裝置的離線語音辨識不支援 ${widget.locale}，下載也沒有用。\n'
            '它支援的語言：${support.supported.isEmpty ? '（無）' : support.supported.join('、')}';
      }
    });
  }

  Future<void> _download() async {
    setState(() {
      _phase = _Phase.downloading;
      _percent = null;
    });

    _sub = _service.downloadEvents.listen((event) {
      if (!mounted) return;
      switch (event.stage) {
        case ModelDownloadStage.progress:
          setState(() => _percent = event.percent);
        case ModelDownloadStage.success:
          setState(() => _phase = _Phase.done);
        case ModelDownloadStage.error:
          setState(() {
            _phase = _Phase.blocked;
            _blockedReason = '下載失敗（錯誤碼 ${event.code}）。'
                '可以改到系統設定裡手動下載。';
          });
        case ModelDownloadStage.scheduled:
        case ModelDownloadStage.unknown:
          break;
      }
    });

    final scheduled = await _service.download(_deviceTag ?? widget.locale);
    if (!mounted) return;
    if (!scheduled) {
      setState(() {
        _phase = _Phase.blocked;
        _blockedReason = '這台裝置無法由 App 觸發下載，請到系統設定裡手動下載。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            _title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppTheme.ink.withOpacity(0.75),
            ),
          ),
          if (_phase == _Phase.downloading) ...[
            const SizedBox(height: 18),
            LinearProgressIndicator(
              value: _percent == null ? null : _percent! / 100,
              backgroundColor: AppTheme.blush.withOpacity(0.4),
              color: AppTheme.rose,
            ),
          ],
          const SizedBox(height: 22),
          ..._actions(context),
        ],
      ),
    );
  }

  String get _emoji => switch (_phase) {
        _Phase.checking => '🔍',
        _Phase.needsDownload => '📦',
        _Phase.downloading => '⬇️',
        _Phase.done => '✅',
        _Phase.blocked => '😢',
      };

  String get _title => switch (_phase) {
        _Phase.checking => '檢查中…',
        _Phase.needsDownload => '她還缺一包中文',
        _Phase.downloading => '正在下載中文語音包',
        _Phase.done => '準備好了',
        _Phase.blocked => '這台裝置沒辦法聽中文',
      };

  String get _message => switch (_phase) {
        _Phase.checking => '正在確認這台手機的語音辨識支援哪些語言。',
        _Phase.needsDownload =>
          '你的手機還沒下載中文語音包，所以她聽不懂中文。\n'
              '按下面的按鈕就會開始下載，只要做這一次。\n'
              '（約數十 MB，建議連 Wi-Fi）',
        _Phase.downloading => _percent == null
            ? '已經交給系統處理，可能需要幾分鐘。\n下載完成後就可以直接用。'
            : '下載中，請稍候…',
        _Phase.done => '中文語音包已經就緒，可以開始跟她說話了。',
        _Phase.blocked => _blockedReason,
      };

  List<Widget> _actions(BuildContext context) {
    switch (_phase) {
      case _Phase.checking:
        return [const CircularProgressIndicator(color: AppTheme.rose)];

      case _Phase.needsDownload:
        return [
          _primaryButton('下載中文語音包', _download),
          _textButton('先不要', () => Navigator.of(context).pop(false)),
        ];

      case _Phase.downloading:
        return [
          _textButton('在背景下載，我先關掉', () => Navigator.of(context).pop(false)),
        ];

      case _Phase.done:
        return [
          _primaryButton('再試一次', () => Navigator.of(context).pop(true)),
        ];

      case _Phase.blocked:
        return [
          _primaryButton('開啟系統語音設定', () async {
            await _service.openVoiceInputSettings();
          }),
          _textButton('知道了', () => Navigator.of(context).pop(false)),
        ];
    }
  }

  Widget _primaryButton(String label, VoidCallback onPressed) => SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.rose,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: onPressed,
          child: Text(label),
        ),
      );

  Widget _textButton(String label, VoidCallback onPressed) => TextButton(
        onPressed: onPressed,
        child: Text(
          label,
          style: TextStyle(color: AppTheme.ink.withOpacity(0.5)),
        ),
      );
}
