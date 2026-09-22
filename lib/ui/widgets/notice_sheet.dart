import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// 使用者在提示面板上選了什麼
enum NoticeAction {
  /// 主要按鈕（再試一次 / 前往設定）
  primary,

  /// 關閉
  dismiss,
}

/// 通用提示面板。目前用於麥克風權限被拒、裝置沒有語音辨識服務等情況。
Future<NoticeAction?> showNoticeSheet(
  BuildContext context, {
  required String emoji,
  required String title,
  required String message,
  required String primaryLabel,
  String dismissLabel = '先不要',
}) {
  return showModalBottomSheet<NoticeAction>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: AppTheme.ink.withOpacity(0.75),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.rose,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(NoticeAction.primary),
                child: Text(primaryLabel),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(NoticeAction.dismiss),
              child: Text(
                '先不要',
                style: TextStyle(color: AppTheme.ink.withOpacity(0.5)),
              ),
            ),
          ],
        ),
      );
    },
  );
}
