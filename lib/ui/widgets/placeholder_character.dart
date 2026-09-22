import 'package:flutter/material.dart';

import '../../core/character_pose.dart';
import 'character_motion.dart';
import 'painters/wife_painter.dart';

/// 佔位角色：純向量畫出來的她，不吃任何 asset。
///
/// 這是三層渲染器最底下的保底（Rive > 圖片 > 這裡），所以它**不能**依賴任何
/// 檔案存在——素材全缺時畫面上也還要有個人。
/// 真正的筆觸在 [WifePainter]，呼吸與歪頭由 [CharacterMotion] 套在外面。
class PlaceholderCharacter extends StatelessWidget {
  const PlaceholderCharacter({super.key, required this.pose});

  final CharacterPose pose;

  @override
  Widget build(BuildContext context) {
    return CharacterMotion(
      pose: pose,
      builder: (context, t) => CustomPaint(
        size: const Size(WifePainter.designWidth, WifePainter.designHeight),
        painter: WifePainter(pose: pose, t: t),
      ),
    );
  }
}
