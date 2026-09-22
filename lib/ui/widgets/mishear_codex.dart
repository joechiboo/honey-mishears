import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/mishear_discovery.dart';
import '../../data/mishear_rule.dart';

/// 梗圖鑑：只攤開使用者自己觸發過的梗。
///
/// 這裡刻意不是一份說明書。一次把所有規則列出來等於先把笑點講完，
/// 使用者剩下的事就只是照稿唸一遍，而「她認真地誤會了」的那個瞬間
/// 只有在不知道會發生什麼的時候才好笑。沒解鎖的那幾筆只給設定檔裡的
/// hint 當謎面，指得到路但不講破諧音。
///
/// 長按標題可以整本翻開——開發時要對著關鍵字清單測辨識，
/// 不能因為藏梗就把那條路也一起封掉。
Future<void> showMishearCodex(
  BuildContext context, {
  required MishearConfig config,
  required MishearDiscovery discovery,
  required Widget diagnostics,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _CodexDialog(
      config: config,
      discovery: discovery,
      diagnostics: diagnostics,
    ),
  );
}

class _CodexDialog extends StatefulWidget {
  const _CodexDialog({
    required this.config,
    required this.discovery,
    required this.diagnostics,
  });

  final MishearConfig config;
  final MishearDiscovery discovery;
  final Widget diagnostics;

  @override
  State<_CodexDialog> createState() => _CodexDialogState();
}

class _CodexDialogState extends State<_CodexDialog> {
  /// 開發用的整本翻開。只活在這次開啟的對話框裡，不寫進裝置。
  bool _revealAll = false;

  @override
  Widget build(BuildContext context) {
    final rules = widget.config.rules;
    final found = rules.where((r) => widget.discovery.has(r.id)).length;
    final allFound = found >= rules.length;

    return AlertDialog(
      title: GestureDetector(
        onLongPress: () => setState(() => _revealAll = true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('梗圖鑑'),
            const SizedBox(height: 4),
            Text(
              allFound
                  ? '$found / ${rules.length}　全部被你找到了'
                  : '$found / ${rules.length}　剩下的自己說說看',
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
            for (final rule in rules) ...[
              _entry(rule, unlocked: _revealAll || widget.discovery.has(rule.id)),
              const SizedBox(height: 14),
            ],
            Text(
              '其他內容她一律歪頭裝傻。',
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

  Widget _entry(MishearRule rule, {required bool unlocked}) {
    if (!unlocked) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 16, color: AppTheme.ink.withOpacity(0.35)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              rule.hint.isEmpty ? '還沒被你說出來過。' : rule.hint,
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
                rule.keywords.join('、'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '→ 她會聽成「${rule.mishearAs}」，然後${rule.label}',
                style: TextStyle(color: AppTheme.ink.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
