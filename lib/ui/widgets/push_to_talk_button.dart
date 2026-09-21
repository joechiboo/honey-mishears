import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';

/// 按住說話按鈕。
///
/// 用 Listener 監聽指標按下／放開，比 GestureDetector 的 onLongPress 更貼近
/// 「按住就開始、放開就結束」的直覺，也不會有長按判定的延遲。
class PushToTalkButton extends StatelessWidget {
  const PushToTalkButton({
    super.key,
    required this.isListening,
    required this.enabled,
    required this.onPressStart,
    required this.onPressEnd,
  });

  final bool isListening;
  final bool enabled;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;

  @override
  Widget build(BuildContext context) {
    final Color color = !enabled
        ? Colors.grey.shade400
        : (isListening ? AppTheme.deepRose : AppTheme.rose);

    return Listener(
      onPointerDown: (_) {
        if (!enabled) return;
        HapticFeedback.lightImpact();
        onPressStart();
      },
      onPointerUp: (_) {
        if (!enabled) return;
        onPressEnd();
      },
      onPointerCancel: (_) {
        if (!enabled) return;
        onPressEnd();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: isListening ? 200 : 180,
        height: 64,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isListening ? 0.5 : 0.3),
              blurRadius: isListening ? 24 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isListening ? Icons.graphic_eq : Icons.mic,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              isListening ? '聽你說…放開結束' : '按住說話',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
