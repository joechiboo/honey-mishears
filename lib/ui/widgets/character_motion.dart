import 'package:flutter/material.dart';

import '../../core/character_pose.dart';

/// 三種角色渲染器共用的「待機微動作」：呼吸縮放 + 依姿勢決定的傾斜。
///
/// 集中在這裡是為了讓佔位角色與圖片角色的體感一致——
/// 新增姿勢時只要補一筆 [_tiltFor]，兩邊同時生效，不會有一邊忘了改。
/// （Rive 角色不吃這個，它的動作全由狀態機自己負責。）
class CharacterMotion extends StatefulWidget {
  const CharacterMotion({super.key, required this.pose, required this.builder});

  final CharacterPose pose;

  /// [t] 是 0→1→0 的循環值。需要額外擺動的部件（例如掃把）可以拿去用，
  /// 不必再開一個自己的 AnimationController。
  final Widget Function(BuildContext context, double t) builder;

  @override
  State<CharacterMotion> createState() => _CharacterMotionState();
}

class _CharacterMotionState extends State<CharacterMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Transform.rotate(
          angle: _tiltFor(widget.pose, t),
          child: Transform.scale(
            // 呼吸：輕微縮放
            scale: 1.0 + 0.015 * t,
            child: widget.builder(context, t),
          ),
        );
      },
    );
  }
}

/// 每個姿勢的身體傾斜（弧度）。回傳值會隨 [t] 變化的就是會晃的姿勢。
double _tiltFor(CharacterPose pose, double t) {
  switch (pose) {
    case CharacterPose.clean:
      return (t - 0.5) * 0.16; // 掃地：左右擺動
    case CharacterPose.confused:
      return 0.18; // 裝傻：固定歪頭
    case CharacterPose.listening:
      return -0.04; // 聆聽：微微前傾
    case CharacterPose.mask:
      return 0; // 敷著泥，不敢亂動
    case CharacterPose.sitting:
      return 0; // 坐得直挺挺，這份「乖」就是笑點
    case CharacterPose.scrolling:
      return 0.05 + (t - 0.5) * 0.02; // 滑手機：固定微駝，再加一點點晃
    case CharacterPose.idle:
    case CharacterPose.lottery:
      return 0;
  }
}
