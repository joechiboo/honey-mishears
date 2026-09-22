import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/character_pose.dart';
import '../../data/mishear_rule.dart';
import '../../services/lottery_generator.dart';
import 'character_renderer.dart';
import 'dust_effect.dart';
import 'image_character.dart';
import 'lottery_card.dart';
import 'painters/room_painter.dart';
import 'placeholder_character.dart';
import 'rive_character.dart';

/// 角色舞台：背景 + 角色 + 情境特效。
///
/// [assets] 由外層啟動時掃描素材決定（見 resolveCharacterAssets）；
/// 三種渲染器吃同一組 CharacterPose，所以之後換素材不必改這裡以外的程式。
class CharacterStage extends StatelessWidget {
  const CharacterStage({
    super.key,
    required this.pose,
    required this.effect,
    required this.assets,
    this.lotteryDraw,
  });

  final CharacterPose pose;
  final StageEffect effect;
  final CharacterAssets assets;
  final LotteryDraw? lotteryDraw;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 房間：牆、地板、窗、掛畫、地毯、盆栽
        const Positioned.fill(
          child: CustomPaint(painter: RoomPainter()),
        ),

        // 角色身後的光暈。房間畫進來之後它的作用變了——
        // 不再是裝飾，而是把她從牆面上拉開一層，不然人跟背景會黏在一起
        Container(
          width: 300,
          height: 300,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppTheme.cream.withOpacity(0.55),
                AppTheme.cream.withOpacity(0.0),
              ],
            ),
          ),
        ),

        // 打掃情境：滿天灰塵
        if (effect == StageEffect.dust) const Positioned.fill(child: DustEffect()),

        // 角色本人
        Align(
          alignment: const Alignment(0, 0.15),
          child: _buildCharacter(),
        ),

        // 報明牌情境：號碼卡（含娛樂性質聲明）
        if (effect == StageEffect.lottery && lotteryDraw != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 0,
            child: LotteryCard(draw: lotteryDraw!),
          ),
      ],
    );
  }

  Widget _buildCharacter() {
    switch (assets.renderer) {
      case CharacterRenderer.rive:
        return SizedBox(
          width: 260,
          height: 300,
          child: RiveCharacter(pose: pose),
        );
      case CharacterRenderer.image:
        return ImageCharacter(pose: pose, availablePoses: assets.imagePoses);
      case CharacterRenderer.placeholder:
        return PlaceholderCharacter(pose: pose);
    }
  }
}
