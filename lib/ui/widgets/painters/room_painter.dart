import 'package:flutter/material.dart';

/// 她待著的房間。
///
/// 跟 [WifePainter] 不一樣：舞台是 Expanded、尺寸隨手機變，
/// 所以這裡所有座標都用畫布比例算，不能寫死像素。
///
/// 設計原則是**背景要退到後面**：低對比、低飽和，深色只留給地板接縫。
/// 角色是主角，房間搶戲就錯了——所以窗戶、掛畫、盆栽都擺在兩側，
/// 中間整條留給她跟明牌卡。
class RoomPainter extends CustomPainter {
  const RoomPainter();

  // 牆
  static const Color _wallTop = Color(0xFFF4EDF6);
  static const Color _wallBottom = Color(0xFFFFF4EE);
  static const Color _baseboard = Color(0xFFE6DAE2);
  // 地板
  static const Color _floorNear = Color(0xFFE9D5C3);
  static const Color _floorFar = Color(0xFFDFC5AF);
  static const Color _floorLine = Color(0xFFCBAE97);
  // 家具小物
  static const Color _frameWood = Color(0xFFD8BEA8);
  static const Color _glass = Color(0xFFDDE9F1);
  static const Color _white = Color(0xFFFFFCFA);
  static const Color _curtain = Color(0xFFF7C8D0);
  static const Color _leaf = Color(0xFFA9C39A);
  static const Color _pot = Color(0xFFD69C7F);
  static const Color _rose = Color(0xFFE79AA8);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // 牆與地板的交界。放在 0.72 是因為角色的裙襬大約落在 0.85，
    // 交界線要在她身後、又不能低到被裙子整條蓋掉
    final horizon = h * 0.72;

    _wall(canvas, w, horizon);
    _floor(canvas, w, h, horizon);
    _window(canvas, w, h);
    _pictureFrame(canvas, w, h);
    _rug(canvas, w, h, horizon);
    _plant(canvas, w, h, horizon);
  }

  void _wall(Canvas canvas, double w, double horizon) {
    final rect = Rect.fromLTWH(0, 0, w, horizon);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_wallTop, _wallBottom],
        ).createShader(rect),
    );
  }

  void _floor(Canvas canvas, double w, double h, double horizon) {
    final rect = Rect.fromLTWH(0, horizon, w, h - horizon);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_floorFar, _floorNear],
        ).createShader(rect),
    );

    // 踢腳板：牆與地板之間的那道深色，整個房間的立體感幾乎都靠它
    canvas.drawRect(
      Rect.fromLTWH(0, horizon - h * 0.018, w, h * 0.018),
      Paint()..color = _baseboard,
    );

    // 木地板接縫。往下逐漸拉寬，假造一點透視
    final line = Paint()
      ..strokeWidth = 1.2
      ..color = _floorLine.withOpacity(0.35);
    for (var i = 1; i <= 3; i++) {
      final y = horizon + (h - horizon) * (i / 3.6);
      canvas.drawLine(Offset(0, y), Offset(w, y), line);
    }
  }

  /// 左側的窗，透進來的光是整個畫面唯一的冷色
  void _window(Canvas canvas, double w, double h) {
    final frame = Rect.fromLTWH(w * 0.04, h * 0.10, w * 0.23, h * 0.30);
    final r = RRect.fromRectAndRadius(frame, const Radius.circular(6));

    canvas.drawRRect(r, Paint()..color = _white);
    final glass = frame.deflate(frame.width * 0.06);
    canvas.drawRRect(
      RRect.fromRectAndRadius(glass, const Radius.circular(3)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_glass, Color(0xFFF0F6FA)],
        ).createShader(glass),
    );
    // 窗櫺
    final bar = Paint()
      ..strokeWidth = 3
      ..color = _white;
    canvas.drawLine(
      Offset(glass.center.dx, glass.top),
      Offset(glass.center.dx, glass.bottom),
      bar,
    );
    canvas.drawLine(
      Offset(glass.left, glass.center.dy),
      Offset(glass.right, glass.center.dy),
      bar,
    );

    // 窗簾：只掛右邊一片，對稱會顯得呆。
    // 要有簾桿、而且寬度要夠——窄窄一條掛在窗邊只會像插了根粉色棍子
    final rodY = frame.top - h * 0.022;
    canvas.drawLine(
      Offset(frame.left - w * 0.012, rodY),
      Offset(frame.right + w * 0.055, rodY),
      Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = _frameWood,
    );

    final curtainLeft = frame.right - frame.width * 0.22;
    final curtainRight = frame.right + w * 0.05;
    final curtainBottom = frame.bottom + h * 0.035;
    canvas.drawPath(
      Path()
        ..moveTo(curtainLeft, rodY)
        ..lineTo(curtainRight, rodY)
        ..cubicTo(curtainRight + w * 0.004, frame.center.dy, curtainRight,
            frame.bottom, curtainRight - w * 0.006, curtainBottom)
        // 下襬做三個波浪，布才有垂感
        ..cubicTo(
            curtainRight - w * 0.022,
            curtainBottom + h * 0.012,
            curtainLeft + w * 0.024,
            curtainBottom - h * 0.014,
            curtainLeft + w * 0.006,
            curtainBottom - h * 0.004)
        ..cubicTo(curtainLeft - w * 0.004, frame.bottom, curtainLeft,
            frame.center.dy, curtainLeft, rodY)
        ..close(),
      Paint()..color = _curtain.withOpacity(0.8),
    );
    // 一道摺線，不然整片會是平的
    canvas.drawPath(
      Path()
        ..moveTo(curtainLeft + (curtainRight - curtainLeft) * 0.45, rodY)
        ..cubicTo(
            curtainLeft + (curtainRight - curtainLeft) * 0.52,
            frame.center.dy,
            curtainLeft + (curtainRight - curtainLeft) * 0.4,
            frame.bottom,
            curtainLeft + (curtainRight - curtainLeft) * 0.48,
            curtainBottom - h * 0.008),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFFE79AA8).withOpacity(0.45),
    );
  }

  /// 右側牆上的掛畫，裡面放一顆心——她的房間
  void _pictureFrame(Canvas canvas, double w, double h) {
    final outer = Rect.fromLTWH(w * 0.76, h * 0.14, w * 0.17, h * 0.15);
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer, const Radius.circular(4)),
      Paint()..color = _frameWood,
    );
    final inner = outer.deflate(outer.width * 0.09);
    canvas.drawRect(inner, Paint()..color = _white);

    // 心形：兩個圓加一個三角，最省事又看得出來
    final cx = inner.center.dx;
    final cy = inner.center.dy;
    final s = inner.width * 0.22;
    final heart = Paint()..color = _rose.withOpacity(0.65);
    canvas.drawCircle(Offset(cx - s * 0.55, cy - s * 0.35), s * 0.62, heart);
    canvas.drawCircle(Offset(cx + s * 0.55, cy - s * 0.35), s * 0.62, heart);
    canvas.drawPath(
      Path()
        ..moveTo(cx - s * 1.1, cy - s * 0.1)
        ..lineTo(cx + s * 1.1, cy - s * 0.1)
        ..lineTo(cx, cy + s * 1.15)
        ..close(),
      heart,
    );
  }

  /// 腳下的地毯，順便把角色跟地板黏在一起（沒有它她會像浮著）
  void _rug(Canvas canvas, double w, double h, double horizon) {
    final rect = Rect.fromCenter(
      center: Offset(w * 0.5, horizon + (h - horizon) * 0.62),
      width: w * 0.82,
      height: (h - horizon) * 0.9,
    );
    canvas.drawOval(rect, Paint()..color = _rose.withOpacity(0.16));
    canvas.drawOval(
      rect.deflate(rect.width * 0.06),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _rose.withOpacity(0.22),
    );
  }

  void _plant(Canvas canvas, double w, double h, double horizon) {
    final baseY = horizon + (h - horizon) * 0.34;
    final cx = w * 0.88;
    final potW = w * 0.09;

    // 葉子：三片杏仁形，角度與長度都錯開。
    // 用細長的曲線畫過一版，看起來是三根草——葉子要夠寬才像葉子。
    final leaf = Paint()..color = _leaf;
    for (final spec in const [
      [-0.55, 0.78, 0.30],
      [0.02, 1.00, 0.34],
      [0.50, 0.72, 0.28],
    ]) {
      final tilt = spec[0];
      final len = spec[1] * h * 0.11;
      final fat = spec[2];

      final tip = Offset(cx + tilt * potW * 1.6, baseY - len);
      final stem = tip - Offset(cx, baseY);
      final norm = stem.distance;
      // 垂直於葉脈的方向，用來把兩側控制點推開成杏仁形
      final perp = Offset(-stem.dy / norm, stem.dx / norm) * (potW * fat);
      final mid = Offset((cx + tip.dx) / 2, (baseY + tip.dy) / 2);

      canvas.drawPath(
        Path()
          ..moveTo(cx, baseY)
          ..quadraticBezierTo(
              mid.dx + perp.dx, mid.dy + perp.dy, tip.dx, tip.dy)
          ..quadraticBezierTo(mid.dx - perp.dx, mid.dy - perp.dy, cx, baseY)
          ..close(),
        leaf,
      );
      // 葉脈
      canvas.drawLine(
        Offset(cx, baseY),
        tip,
        Paint()
          ..strokeWidth = 1
          ..color = const Color(0xFF8CA87C).withOpacity(0.5),
      );
    }

    // 盆：上寬下窄的梯形
    canvas.drawPath(
      Path()
        ..moveTo(cx - potW * 0.5, baseY - h * 0.005)
        ..lineTo(cx + potW * 0.5, baseY - h * 0.005)
        ..lineTo(cx + potW * 0.36, baseY + h * 0.05)
        ..lineTo(cx - potW * 0.36, baseY + h * 0.05)
        ..close(),
      Paint()..color = _pot,
    );
    canvas.drawRect(
      Rect.fromLTWH(cx - potW * 0.54, baseY - h * 0.012, potW * 1.08, h * 0.012),
      Paint()..color = _pot.withOpacity(0.85),
    );
  }

  @override
  bool shouldRepaint(covariant RoomPainter oldDelegate) => false;
}
