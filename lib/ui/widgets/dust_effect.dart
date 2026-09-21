import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 打掃情境的灰塵特效：幾顆灰色小圓點在畫面裡飄。
/// 純裝飾，Rive 素材完成後可以改由 Rive 自己畫。
class DustEffect extends StatefulWidget {
  const DustEffect({super.key});

  @override
  State<DustEffect> createState() => _DustEffectState();
}

class _DustEffectState extends State<DustEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Mote> _motes;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // 固定亂數種子，讓灰塵分布每次都一樣，方便除錯
    final random = math.Random(42);
    _motes = List.generate(
      12,
      (i) => _Mote(
        dx: random.nextDouble(),
        baseDy: random.nextDouble(),
        size: 4 + random.nextDouble() * 7,
        speed: 0.3 + random.nextDouble() * 0.7,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  for (final mote in _motes) _buildMote(mote, constraints),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMote(_Mote mote, BoxConstraints constraints) {
    // 由下往上飄，超出畫面後從底部回來
    final progress = (mote.baseDy + _controller.value * mote.speed) % 1.0;
    final top = constraints.maxHeight * (1 - progress);

    // 頭尾淡出，中間最明顯
    final opacity = math.sin(progress * math.pi).clamp(0.0, 1.0) * 0.5;

    return Positioned(
      left: constraints.maxWidth * mote.dx,
      top: top,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: mote.size,
          height: mote.size,
          decoration: const BoxDecoration(
            color: Color(0xFFB0A8A2),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _Mote {
  const _Mote({
    required this.dx,
    required this.baseDy,
    required this.size,
    required this.speed,
  });

  final double dx;
  final double baseDy;
  final double size;
  final double speed;
}
