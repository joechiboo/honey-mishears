import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/memories.dart';

/// 我們的回憶：只寫下真的發生過的事。
///
/// 這裡刻意不是一份說明書。一次把所有規則列出來等於先把笑點講完，
/// 使用者剩下的事就只是照稿唸一遍，而「她認真地誤會了」的那個瞬間
/// 只有在不知道會發生什麼的時候才好笑。還沒發生的那幾則只留一句
/// 曖昧的話——那是期待，不是待辦清單。
///
/// 長按標題可以整本翻開——開發時要對著關鍵字清單測辨識，
/// 不能因為藏梗就把那條路也一起封掉。
Future<void> showMemoryAlbum(
  BuildContext context, {
  required List<MemoryEntry> entries,
  required Memories memories,
  required Widget diagnostics,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _AlbumDialog(
      entries: entries,
      memories: memories,
      diagnostics: diagnostics,
    ),
  );
}

class _AlbumDialog extends StatefulWidget {
  const _AlbumDialog({
    required this.entries,
    required this.memories,
    required this.diagnostics,
  });

  final List<MemoryEntry> entries;
  final Memories memories;
  final Widget diagnostics;

  @override
  State<_AlbumDialog> createState() => _AlbumDialogState();
}

class _AlbumDialogState extends State<_AlbumDialog> {
  /// 開發用的整本翻開。只活在這次開啟的對話框裡，不寫進裝置。
  bool _revealAll = false;

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final happened = entries.where((e) => widget.memories.has(e.id)).length;

    return AlertDialog(
      title: GestureDetector(
        onLongPress: () => setState(() => _revealAll = true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('我們的回憶'),
            const SizedBox(height: 4),
            Text(
              _subtitle(happened, entries.length),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppTheme.ink.withOpacity(0.55),
              ),
            ),
          ],
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in entries) ...[
              _row(entry,
                  happened: _revealAll || widget.memories.has(entry.id)),
              const SizedBox(height: 14),
            ],
            Text(
              '其他時候她一律歪頭裝傻。',
              style: TextStyle(color: AppTheme.ink.withOpacity(0.5), fontSize: 12),
            ),
            if (_revealAll) ...[
              const Divider(height: 24),
              widget.diagnostics,
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      ],
    );
  }

  /// 副標。一則都還沒有的時候不要報 0／n——
  /// 那是進度條的語氣，會把整本變回待辦清單。
  static String _subtitle(int happened, int total) {
    if (happened == 0) return '還沒有故事，跟她說說話吧';
    if (happened >= total) return '$happened 則．我們什麼都做過了';
    return '$happened 則．還有沒發生的事';
  }

  Widget _row(MemoryEntry entry, {required bool happened}) {
    if (!happened) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.more_horiz, size: 16, color: AppTheme.ink.withOpacity(0.35)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.hint,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppTheme.ink.withOpacity(0.55),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.favorite, size: 16, color: AppTheme.rose),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                entry.detail,
                style: TextStyle(color: AppTheme.ink.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
