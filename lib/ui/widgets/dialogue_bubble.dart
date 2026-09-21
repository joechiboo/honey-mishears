import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// 台詞對話框。
///
/// [mishearAs] 有值時會在上方顯示「她聽成：清一個」的小標，
/// 這是整個笑點的關鍵：讓使用者看到她「認真地誤會」了什麼。
class DialogueBubble extends StatelessWidget {
  const DialogueBubble({
    super.key,
    required this.text,
    this.mishearAs,
    this.spokenText,
  });

  final String text;
  final String? mishearAs;

  /// 語音辨識實際聽到的內容，顯示在角落方便測試／讓使用者知道說錯話了
  final String? spokenText;

  @override
  Widget build(BuildContext context) {
    final hasMishear = mishearAs != null && mishearAs!.isNotEmpty;

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 108),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.blush, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.rose.withOpacity(0.15),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasMishear) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.lavender.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '她聽成「$mishearAs」',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.deepRose,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                height: 1.5,
                color: AppTheme.ink,
              ),
            ),
            if (spokenText != null && spokenText!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '（你剛剛說：$spokenText）',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.ink.withOpacity(0.45),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
