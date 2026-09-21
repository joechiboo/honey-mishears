import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/lottery_generator.dart';

/// 報明牌的號碼卡。
///
/// ⚠️ Google Play 規範：這是娛樂性質內容，不得讓使用者誤以為具有預測能力，
///    因此卡片上「必須」顯示號碼為隨機產生的聲明。請勿移除 _disclaimer。
class LotteryCard extends StatelessWidget {
  const LotteryCard({super.key, required this.draw});

  final LotteryDraw draw;

  static const String disclaimerText = '僅供娛樂，號碼為電腦隨機產生，不具任何預測性，與真實彩券開獎無關。';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.blush, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.rose.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🕶️', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                '老婆牌明牌',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.deepRose,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final n in draw.numbers) _NumberBall(number: n),
              // 特別號用不同顏色區隔
              _NumberBall(number: draw.special, isSpecial: true),
            ],
          ),
          const SizedBox(height: 12),
          _disclaimer(context),
        ],
      ),
    );
  }

  /// 娛樂性質聲明（Google Play 上架必要，勿刪）
  Widget _disclaimer(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8C9A0)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 14, color: Color(0xFF9A6B2F)),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              disclaimerText,
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: Color(0xFF8A5F2A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberBall extends StatelessWidget {
  const _NumberBall({required this.number, this.isSpecial = false});

  final int number;
  final bool isSpecial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSpecial ? AppTheme.deepRose : AppTheme.lavender,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$number',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: isSpecial ? Colors.white : AppTheme.ink,
        ),
      ),
    );
  }
}
