import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/character_pose.dart';

/// 佔位角色：在 Rive 素材完成前，用純 Flutter 圖形畫一個簡單的 2D 角色。
/// 目標只有一個 —— 看得出「她現在是什麼狀態」，不追求精緻。
class PlaceholderCharacter extends StatefulWidget {
  const PlaceholderCharacter({super.key, required this.pose});

  final CharacterPose pose;

  @override
  State<PlaceholderCharacter> createState() => _PlaceholderCharacterState();
}

class _PlaceholderCharacterState extends State<PlaceholderCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const Color _skin = Color(0xFFFCE3D6);
  static const Color _hair = Color(0xFF6E4B3A);

  @override
  void initState() {
    super.initState();
    // 一個共用的 0→1→0 循環，拿來做呼吸、掃地擺動等簡單動畫
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
      builder: (context, child) {
        final t = _controller.value;

        // 呼吸：輕微縮放
        final breathe = 1.0 + 0.015 * t;

        // 打掃時左右擺動，裝傻時固定歪頭，聆聽時微微前傾
        double tilt = 0;
        if (widget.pose == CharacterPose.clean) {
          tilt = (t - 0.5) * 0.16;
        } else if (widget.pose == CharacterPose.confused) {
          tilt = 0.18;
        } else if (widget.pose == CharacterPose.listening) {
          tilt = -0.04;
        }

        return Transform.rotate(
          angle: tilt,
          child: Transform.scale(scale: breathe, child: child),
        );
      },
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    return SizedBox(
      width: 220,
      height: 280,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // 身體
          Positioned(
            bottom: 0,
            child: Container(
              width: 150,
              height: 130,
              decoration: const BoxDecoration(
                color: AppTheme.blush,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(70),
                  bottom: Radius.circular(20),
                ),
              ),
            ),
          ),
          // 後髮
          Positioned(
            top: 6,
            child: Container(
              width: 176,
              height: 196,
              decoration: BoxDecoration(
                color: _hair,
                borderRadius: BorderRadius.circular(88),
              ),
            ),
          ),
          // 臉
          Positioned(
            top: 26,
            child: Container(
              width: 148,
              height: 158,
              decoration: BoxDecoration(
                color: _skin,
                borderRadius: BorderRadius.circular(74),
              ),
              child: _buildFace(),
            ),
          ),
          // 瀏海
          Positioned(
            top: 14,
            child: Container(
              width: 168,
              height: 74,
              decoration: const BoxDecoration(
                color: _hair,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(84),
                  bottom: Radius.circular(40),
                ),
              ),
            ),
          ),
          // 打掃時手上的掃把
          if (widget.pose == CharacterPose.clean)
            Positioned(
              right: 0,
              bottom: 12,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => Transform.rotate(
                  angle: -0.5 + (_controller.value - 0.5) * 0.7,
                  child: child,
                ),
                child: const Text('🧹', style: TextStyle(fontSize: 56)),
              ),
            ),
          // 裝傻時頭上的問號
          if (widget.pose == CharacterPose.confused)
            const Positioned(
              top: 0,
              right: 14,
              child: Text('❓', style: TextStyle(fontSize: 28)),
            ),
        ],
      ),
    );
  }

  Widget _buildFace() {
    // 敷泥膜：整張臉蓋一層泥，眼睛壓兩片小黃瓜
    if (widget.pose == CharacterPose.mask) {
      return Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF9CB38A).withOpacity(0.88),
                borderRadius: BorderRadius.circular(70),
              ),
            ),
          ),
          Positioned(
            top: 50,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _cucumber(),
                const SizedBox(width: 30),
                _cucumber(),
              ],
            ),
          ),
          Positioned(top: 106, child: _mouth(width: 16)),
        ],
      );
    }

    // 報明牌時戴墨鏡，其他狀態畫眼睛
    if (widget.pose == CharacterPose.lottery) {
      return Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 58,
            child: Container(
              width: 116,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF2B2B2B),
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
          Positioned(top: 104, child: _mouth(width: 26)),
        ],
      );
    }

    final bool wide = widget.pose == CharacterPose.listening;
    final double eyeHeight = wide ? 22 : 18;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          top: 56,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _eye(eyeHeight),
              const SizedBox(width: 44),
              _eye(eyeHeight),
            ],
          ),
        ),
        Positioned(
          top: 84,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _blush(),
              const SizedBox(width: 60),
              _blush(),
            ],
          ),
        ),
        Positioned(
          top: 100,
          child: _mouth(width: widget.pose == CharacterPose.confused ? 14 : 22),
        ),
      ],
    );
  }

  Widget _eye(double height) => Container(
        width: 16,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.ink,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 3),
        child: Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      );

  /// 敷臉用的小黃瓜片
  Widget _cucumber() => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFFCDE6B0),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF7FA05C), width: 3),
        ),
      );

  Widget _blush() => Container(
        width: 22,
        height: 12,
        decoration: BoxDecoration(
          color: AppTheme.rose.withOpacity(0.45),
          borderRadius: BorderRadius.circular(11),
        ),
      );

  /// 上翹的嘴角（把半圓翻過來畫）
  Widget _mouth({required double width}) => Transform.rotate(
        angle: math.pi,
        child: Container(
          width: width,
          height: 10,
          decoration: const BoxDecoration(
            color: AppTheme.deepRose,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
        ),
      );
}
