import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/telemetry_config.dart';
import '../../data/telemetry_store.dart';

/// 首次啟動的告知面板。
///
/// 預設是開的，所以這個面板不是「請求同意」而是「明確告知 + 當場可關」。
/// Play 的要求就是這兩點：說清楚收什麼、關得掉。所以「不要傳送」必須是
/// 跟「知道了」同等大小的選項，不能藏成一行小字。
Future<void> showTelemetryNotice(
  BuildContext context,
  TelemetryStore store,
) async {
  await store.markNoticeShown();
  if (!context.mounted) return;

  final keep = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppTheme.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📝', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 12),
          const Text(
            '關於「她聽不懂的那些話」',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.deepRose,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '為了知道大家會對她說什麼、好補上她聽不懂的梗，'
            'App 會把辨識完的文字傳回開發者（不含錄音）。\n\n'
            '・不會上傳錄音，只有文字\n'
            '・不會上傳你替她取的名字\n'
            '・識別碼是本機隨機產生的，不是你的裝置編號\n\n'
            '隨時可以在右上角的設定關掉，關掉就連還沒送出的一起刪除。',
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppTheme.ink.withOpacity(0.85),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('不要傳送'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('知道了'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  if (keep == false) await store.setEnabled(false);
}

/// 設定面板：開關 + 看得到還沒送出去的內容 + 清空。
///
/// 「看得到送出什麼」是這個面板存在的主要理由。只給一個開關、
/// 不讓人看到內容，等於要使用者憑信任勾同意。
class TelemetrySheet extends StatefulWidget {
  const TelemetrySheet({super.key, required this.store});

  final TelemetryStore store;

  @override
  State<TelemetrySheet> createState() => _TelemetrySheetState();
}

class _TelemetrySheetState extends State<TelemetrySheet> {
  late bool _enabled = widget.store.enabled;

  @override
  Widget build(BuildContext context) {
    final queued = widget.store.queued;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '設定',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.deepRose,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _enabled,
            title: const Text('回傳聽到的文字'),
            subtitle: const Text('只有文字，沒有錄音。用來補她聽不懂的梗。'),
            onChanged: (value) async {
              await widget.store.setEnabled(value);
              if (mounted) setState(() => _enabled = value);
            },
          ),

          if (!TelemetryConfig.configured)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                '這一版沒有設定回傳端點，所以實際上不會傳送任何東西。',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.ink.withOpacity(0.55),
                ),
              ),
            ),

          const Divider(height: 24),

          Text(
            _enabled ? '還沒送出的（${queued.length}）' : '已關閉，佇列已清空',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          if (_enabled && queued.isEmpty)
            Text(
              '目前沒有待送的內容。',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.ink.withOpacity(0.55),
              ),
            ),

          if (_enabled && queued.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView(
                shrinkWrap: true,
                children: [
                  // 新的在上面，比較好對照剛剛說過的話
                  for (final record in queued.reversed)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Text(record.matched ? '✅' : '❓'),
                      title: Text(record.transcript),
                      subtitle: Text(
                        record.matched ? '聽懂了（${record.ruleId}）' : '她裝傻了',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),

          const Divider(height: 24),

          // 識別碼要看得到也複製得走：隱私政策承諾「可以要求刪除自己的紀錄」，
          // 而我們刻意不收任何能識別身分的東西，所以這串是唯一的憑據。
          // 政策上寫得到、App 裡拿不到，那個承諾就是空的。
          Text(
            '這台裝置的識別碼',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.ink.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.store.deviceId,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '複製',
                icon: const Icon(Icons.copy_outlined, size: 18),
                onPressed: () async {
                  // messenger 先抓好再 await：await 之後這個 context
                  // 可能已經不在樹上了
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(
                      ClipboardData(text: widget.store.deviceId));
                  messenger.showSnackBar(
                    const SnackBar(content: Text('識別碼已複製')),
                  );
                },
              ),
            ],
          ),
          Text(
            '要求刪除自己的紀錄時附上這串即可。清除 App 資料會換一組新的。',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.ink.withOpacity(0.5),
            ),
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              if (_enabled && queued.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    await widget.store.setQueued(const []);
                    if (mounted) setState(() {});
                  },
                  child: const Text('清空待送'),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('關閉'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> showTelemetrySheet(BuildContext context, TelemetryStore store) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => TelemetrySheet(store: store),
  );
}
