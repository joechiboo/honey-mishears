import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/character_pose.dart';

/// 佔位角色的向量畫法。
///
/// 全部用 Path 與漸層畫出來，不吃任何 asset——這是素材全缺時的保底，
/// 所以它不能依賴檔案存在。設計座標固定 240 × 300，畫之前先等比縮放，
/// 所以底下所有座標都可以照這張畫布寫死。
///
/// 要調整外觀時，先用 `flutter test tool/render_character_preview.dart`
/// 把六個姿勢畫成 PNG 看過再改，不要憑座標想像。
class WifePainter extends CustomPainter {
  const WifePainter({required this.pose, required this.t});

  final CharacterPose pose;

  /// 0→1→0 的循環值，用來讓掃把擺動
  final double t;

  static const double designWidth = 240;
  static const double designHeight = 300;

  // ── 配色（與 AppTheme 同一家族，另外補了陰影與高光）──────────
  static const Color _skin = Color(0xFFFCE3D6);
  static const Color _skinShade = Color(0xFFF1C6B4);
  static const Color _hair = Color(0xFF6E4B3A);
  static const Color _hairDark = Color(0xFF503327);
  static const Color _hairLight = Color(0xFF9C7058);
  static const Color _dress = Color(0xFFF7C8D0);
  static const Color _dressShade = Color(0xFFE6A2B1);
  static const Color _rose = Color(0xFFE79AA8);
  static const Color _deepRose = Color(0xFFB4687A);
  static const Color _ink = Color(0xFF5B4A50);
  static const Color _eyeWhite = Color(0xFFFFFAFA);
  static const Color _irisTop = Color(0xFF9A5F68);
  static const Color _irisBottom = Color(0xFF3A272C);

  // 臉的範圍，很多部件要對齊它
  static const double _faceCx = 120;
  static const double _faceTop = 38;
  static const double _chinY = 172;

  /// 眼睛中心；報明牌時這兩個位置會被墨鏡蓋住
  static const List<Offset> _eyeCenters = [Offset(95, 114), Offset(145, 114)];

  /// 打掃時握住掃把的位置，右手與掃把都對齊這一點
  static const Offset _broomGrip = Offset(204, 216);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / designWidth);

    _backHair(canvas);
    if (pose == CharacterPose.clean) _broom(canvas);
    _body(canvas);
    _neck(canvas);
    _face(canvas);
    if (pose == CharacterPose.mask) {
      _sheetMask(canvas);
    } else {
      _brows(canvas);
      _eyes(canvas);
      _blush(canvas);
    }
    _mouth(canvas);
    _bangs(canvas);
    if (pose == CharacterPose.confused) _questionMark(canvas);

    canvas.restore();
  }

  // ── 頭髮 ─────────────────────────────────────────────────

  void _backHair(Canvas canvas) {
    final hair = Path()
      ..moveTo(120, 22)
      ..cubicTo(58, 22, 38, 78, 45, 132)
      // 下襬要收在肩線以內，不然兩側會從袖子外緣露出一小截暗色尖角
      ..cubicTo(50, 180, 54, 214, 58, 244)
      ..cubicTo(74, 238, 94, 236, 112, 244)
      ..cubicTo(117, 246, 123, 246, 128, 244)
      ..cubicTo(146, 236, 166, 238, 182, 244)
      ..cubicTo(186, 214, 190, 180, 195, 132)
      ..cubicTo(202, 78, 182, 22, 120, 22)
      ..close();

    canvas.drawPath(
      hair,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_hairLight, _hair, _hairDark],
          stops: [0.0, 0.45, 1.0],
        ).createShader(const Rect.fromLTWH(45, 22, 150, 222)),
    );

    // 髮流：幾道比底色深一點的線，讓髮束看得出來
    final strand = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3
      ..color = _hairDark.withOpacity(0.3);
    for (final x in const [60.0, 76.0, 164.0, 180.0]) {
      final dir = x < 120 ? -1.0 : 1.0;
      canvas.drawPath(
        Path()
          ..moveTo(x, 122)
          ..cubicTo(x + 4 * dir, 170, x - 2 * dir, 208, x + 5 * dir, 240),
        strand,
      );
    }
  }

  /// 瀏海與兩側的髮束，蓋在臉上面
  void _bangs(Canvas canvas) {
    // 中分的柔和瀏海。分線頂端要圓，收成尖角會像被剪壞
    final fringe = Path()
      ..moveTo(58, 106)
      ..cubicTo(54, 52, 86, 28, 121, 28)
      ..cubicTo(157, 28, 187, 52, 183, 106)
      ..cubicTo(178, 88, 170, 76, 158, 70)
      ..cubicTo(152, 94, 140, 106, 126, 110)
      ..cubicTo(132, 86, 132, 66, 126, 54)
      ..cubicTo(121, 47, 113, 50, 109, 61)
      ..cubicTo(101, 83, 86, 98, 70, 100)
      ..cubicTo(64, 96, 60, 100, 58, 106)
      ..close();

    canvas.drawPath(
      fringe,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_hairLight, _hair],
        ).createShader(const Rect.fromLTWH(54, 28, 130, 82)),
    );

    // 髮際高光：動漫常見的那道弧形反光
    canvas.drawPath(
      Path()
        ..moveTo(80, 64)
        ..cubicTo(98, 46, 144, 46, 162, 66)
        ..cubicTo(144, 56, 98, 56, 80, 64)
        ..close(),
      Paint()..color = const Color(0xFFD9B49C).withOpacity(0.45),
    );

    // 兩側順著臉頰垂下來的髮束
    for (final left in const [true, false]) {
      final dir = left ? -1.0 : 1.0;
      final x = 120 + 62 * dir;
      canvas.drawPath(
        Path()
          ..moveTo(x, 78)
          ..cubicTo(x + 6 * dir, 112, x + 2 * dir, 150, x - 4 * dir, 178)
          ..cubicTo(x - 14 * dir, 150, x - 12 * dir, 110, x - 9 * dir, 84)
          ..close(),
        Paint()..color = _hair,
      );
    }
  }

  // ── 身體 ─────────────────────────────────────────────────

  void _body(Canvas canvas) {
    const dressRect = Rect.fromLTWH(38, 182, 164, 118);

    // 肩線直接做出短袖的輪廓。曾經用兩顆橢圓當泡泡袖，
    // 但在這個頭身比下看起來就是胸前掛了兩球，不如讓裙身自己收。
    final dress = Path()
      ..moveTo(102, 182)
      ..lineTo(138, 182)
      ..cubicTo(164, 184, 188, 196, 194, 216)
      ..cubicTo(198, 250, 200, 278, 202, 300)
      ..lineTo(38, 300)
      ..cubicTo(40, 278, 42, 250, 46, 216)
      ..cubicTo(52, 196, 76, 184, 102, 182)
      ..close();

    canvas.drawPath(
      dress,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_dress, _dressShade],
        ).createShader(dressRect),
    );

    _arms(canvas);

    // 袖口：填色的袖蓋，畫在手臂之後，蓋掉手臂上緣的接縫。
    // 用描邊畫過一版，看起來像兩個粉色鉤子浮在手臂上，填色才像衣服。
    for (final left in const [true, false]) {
      final dir = left ? 1.0 : -1.0;
      final x = left ? 44.0 : 196.0;
      canvas.drawPath(
        Path()
          ..moveTo(x, 214)
          ..cubicTo(x + 4 * dir, 232, x + 16 * dir, 244, x + 32 * dir, 240)
          ..cubicTo(x + 26 * dir, 226, x + 16 * dir, 214, x + 6 * dir, 206)
          ..close(),
        // 用裙身同一條漸層填，袖蓋才會跟衣服連成一片；
        // 單獨填 _dress 會在漸層中段變成一塊明顯亮起來的補丁
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_dress, _dressShade],
          ).createShader(dressRect),
      );
      canvas.drawPath(
        Path()
          ..moveTo(x, 214)
          ..cubicTo(x + 4 * dir, 232, x + 16 * dir, 244, x + 32 * dir, 240),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..color = _dressShade,
      );
    }

    // 衣領
    canvas.drawPath(
      Path()
        ..moveTo(102, 182)
        ..cubicTo(109, 197, 131, 197, 138, 182)
        ..cubicTo(131, 191, 109, 191, 102, 182)
        ..close(),
      Paint()..color = const Color(0xFFFFF6F0),
    );

    // 胸前的蝴蝶結
    final bow = Paint()..color = _deepRose;
    canvas.drawPath(
      Path()
        ..moveTo(120, 194)
        ..lineTo(105, 187)
        ..lineTo(105, 202)
        ..close(),
      bow,
    );
    canvas.drawPath(
      Path()
        ..moveTo(120, 194)
        ..lineTo(135, 187)
        ..lineTo(135, 202)
        ..close(),
      bow,
    );
    canvas.drawCircle(const Offset(120, 194), 4.5, Paint()..color = _rose);
  }

  /// 手臂。左手一律垂在身側；右手打掃時往外伸去握掃把。
  void _arms(Canvas canvas) {
    final skin = Paint()..color = _skin;

    canvas.drawPath(
      Path()
        ..moveTo(48, 230)
        ..cubicTo(42, 256, 39, 280, 41, 300)
        ..lineTo(64, 300)
        ..cubicTo(62, 276, 64, 252, 70, 233)
        ..close(),
      skin,
    );

    if (pose == CharacterPose.clean) {
      // 前臂斜斜伸向握把，終點落在 _broomGrip
      canvas.drawPath(
        Path()
          ..moveTo(170, 230)
          ..cubicTo(182, 230, 196, 226, _broomGrip.dx, _broomGrip.dy - 4)
          ..cubicTo(206, 224, 204, 230, 200, 232)
          ..cubicTo(190, 238, 180, 242, 168, 244)
          ..close(),
        skin,
      );
      canvas.drawCircle(_broomGrip, 10.5, skin);
      canvas.drawArc(
        Rect.fromCircle(center: _broomGrip, radius: 10.5),
        math.pi * 0.1,
        math.pi * 0.8,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _skinShade,
      );
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(192, 230)
          ..cubicTo(198, 256, 201, 280, 199, 300)
          ..lineTo(176, 300)
          ..cubicTo(178, 276, 176, 252, 170, 233)
          ..close(),
        skin,
      );
    }
  }

  void _neck(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(105, 144, 30, 46),
        const Radius.circular(13),
      ),
      Paint()..color = _skin,
    );
    // 下巴打在脖子上的陰影
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(120, 154), width: 40, height: 19),
      Paint()..color = _skinShade.withOpacity(0.7),
    );
  }

  // ── 臉 ───────────────────────────────────────────────────

  Path _facePath() => Path()
    ..moveTo(64, 104)
    ..cubicTo(64, 54, 88, _faceTop, _faceCx, _faceTop)
    ..cubicTo(152, _faceTop, 176, 54, 176, 104)
    ..cubicTo(176, 136, 154, 160, _faceCx, _chinY)
    ..cubicTo(86, 160, 64, 136, 64, 104)
    ..close();

  void _face(Canvas canvas) {
    // 耳朵
    for (final cx in const [65.0, 175.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, 116), width: 18, height: 26),
        Paint()..color = _skin,
      );
    }

    canvas.drawPath(
      _facePath(),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF0E7), _skin, _skinShade],
          stops: [0.0, 0.55, 1.0],
        ).createShader(const Rect.fromLTWH(64, 38, 112, 134)),
    );

    // 鼻子：一小點就夠，畫太多會變寫實
    canvas.drawPath(
      Path()
        ..moveTo(117, 133)
        ..cubicTo(120, 137, 123, 137, 125, 134),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = _skinShade,
    );
  }

  void _blush(Canvas canvas) {
    for (final cx in const [86.0, 154.0]) {
      final rect =
          Rect.fromCenter(center: Offset(cx, 136), width: 34, height: 19);
      canvas.drawOval(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [_rose.withOpacity(0.55), _rose.withOpacity(0.0)],
          ).createShader(rect),
      );
    }
  }

  // ── 五官 ─────────────────────────────────────────────────

  void _brows(Canvas canvas) {
    final brow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = _hairDark;

    for (var i = 0; i < 2; i++) {
      final c = _eyeCenters[i];
      final left = i == 0;
      final dir = left ? -1.0 : 1.0;

      // 姿勢決定眉毛的高度與斜度
      double lift = 0;
      double slant = 0;
      switch (pose) {
        case CharacterPose.listening:
          lift = -3; // 挑高：有興趣
          break;
        case CharacterPose.clean:
          slant = 3; // 內側壓低：認真
          break;
        case CharacterPose.confused:
          lift = left ? -5 : 2; // 一高一低：困惑
          break;
        case CharacterPose.idle:
        case CharacterPose.lottery:
        case CharacterPose.mask:
          break;
      }

      final y = c.dy - 27 + lift;
      // 內側端點（靠鼻樑那端）會被 slant 壓低
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - 15 * dir, y + 4 + slant)
          ..cubicTo(c.dx - 6 * dir, y - 3 + slant * 0.4, c.dx + 6 * dir, y - 3,
              c.dx + 15 * dir, y + 2),
        brow,
      );
    }
  }

  void _eyes(Canvas canvas) {
    if (pose == CharacterPose.lottery) {
      _sunglasses(canvas);
      return;
    }

    // 聆聽時眼睛睜大，裝傻時瞳孔往旁邊瞟
    final open = pose == CharacterPose.listening ? 1.14 : 1.0;
    final gaze = pose == CharacterPose.confused ? 2.5 : 0.0;

    for (var i = 0; i < 2; i++) {
      final c = _eyeCenters[i];
      final left = i == 0;
      // 往外眼角的方向
      final out = left ? -1.0 : 1.0;
      final socket = Rect.fromCenter(center: c, width: 30, height: 34 * open);

      // 眼白
      final eye = Path()
        ..moveTo(socket.left, c.dy + 2)
        ..cubicTo(socket.left + 1, socket.top + 2, socket.right - 1,
            socket.top + 2, socket.right, c.dy - 1)
        ..cubicTo(socket.right - 3, socket.bottom, socket.left + 3,
            socket.bottom, socket.left, c.dy + 2)
        ..close();
      canvas.drawPath(eye, Paint()..color = _eyeWhite);

      canvas.save();
      canvas.clipPath(eye);

      // 虹膜：上淺下深，動漫眼的關鍵
      final irisC = Offset(c.dx + gaze, c.dy + 1);
      final iris = Rect.fromCenter(center: irisC, width: 23, height: 27 * open);
      canvas.drawOval(
        iris,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_irisTop, _irisBottom],
          ).createShader(iris),
      );
      // 瞳孔
      canvas.drawOval(
        Rect.fromCenter(center: irisC, width: 11, height: 15 * open),
        Paint()..color = const Color(0xFF241A1E),
      );
      // 虹膜下緣透光，讓眼睛看起來是濕的
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(irisC.dx, irisC.dy + 9), width: 16, height: 8),
        Paint()..color = const Color(0xFFF3C3CB).withOpacity(0.5),
      );
      // 高光：一大一小，位置錯開才有神
      canvas.drawCircle(
        Offset(irisC.dx - 6, irisC.dy - 7),
        5.2,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(irisC.dx + 6, irisC.dy + 6),
        2.4,
        Paint()..color = Colors.white.withOpacity(0.85),
      );

      canvas.restore();

      // 上眼瞼：填色的月牙，中間厚、兩端收尖，外眼角往上挑。
      // 用填色而不是描邊，才收得出尖——描邊只能兩端一樣粗，會像貼了根觸角。
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - 15 * out, c.dy + 2)
          ..cubicTo(c.dx - 9 * out, socket.top - 2, c.dx + 7 * out,
              socket.top - 2, c.dx + 18 * out, c.dy - 8)
          ..cubicTo(c.dx + 11 * out, c.dy - 6, c.dx + 6 * out, c.dy - 10,
              c.dx - 2 * out, c.dy - 11)
          ..cubicTo(c.dx - 8 * out, c.dy - 11, c.dx - 13 * out, c.dy - 6,
              c.dx - 15 * out, c.dy + 2)
          ..close(),
        Paint()..color = _ink,
      );
    }
  }

  void _sunglasses(Canvas canvas) {
    final lens = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4A4550), Color(0xFF1C1A20)],
      ).createShader(const Rect.fromLTWH(74, 98, 92, 34));

    for (final c in _eyeCenters) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: 42, height: 30),
          const Radius.circular(12),
        ),
        lens,
      );
      // 鏡面反光
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - 16, c.dy + 8)
          ..lineTo(c.dx - 6, c.dy - 11)
          ..lineTo(c.dx - 1, c.dy - 11)
          ..lineTo(c.dx - 11, c.dy + 8)
          ..close(),
        Paint()..color = Colors.white.withOpacity(0.28),
      );
    }
    // 鼻樑與鏡腳
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF2B2830);
    canvas.drawLine(const Offset(114, 110), const Offset(126, 110), frame);
    canvas.drawLine(const Offset(74, 110), const Offset(64, 114), frame);
    canvas.drawLine(const Offset(166, 110), const Offset(176, 114), frame);
  }

  void _mouth(Canvas canvas) {
    const y = 152.0;
    switch (pose) {
      case CharacterPose.listening:
        // 微張的小嘴
        canvas.drawOval(
          Rect.fromCenter(
              center: const Offset(120, y + 2), width: 14, height: 12),
          Paint()..color = _deepRose,
        );
        canvas.drawOval(
          Rect.fromCenter(
              center: const Offset(120, y + 5), width: 9, height: 5),
          Paint()..color = const Color(0xFFE38A9B),
        );
        break;
      case CharacterPose.clean:
        // 張嘴的笑：幹勁十足
        canvas.drawPath(
          Path()
            ..moveTo(107, y - 2)
            ..cubicTo(114, y + 12, 126, y + 12, 133, y - 2)
            ..cubicTo(126, y + 2, 114, y + 2, 107, y - 2)
            ..close(),
          Paint()..color = _deepRose,
        );
        break;
      case CharacterPose.lottery:
        // 單邊上揚的得意笑
        canvas.drawPath(
          Path()
            ..moveTo(108, y + 2)
            ..cubicTo(118, y + 8, 128, y + 4, 134, y - 4),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.4
            ..strokeCap = StrokeCap.round
            ..color = _deepRose,
        );
        break;
      case CharacterPose.mask:
        // 敷著面膜，嘴角放鬆上揚。
        // 閉眼配一條平的嘴等於「沒有表情」，很容易讀成陰森
        canvas.drawPath(
          Path()
            ..moveTo(113, y)
            ..cubicTo(117, y + 6, 123, y + 6, 127, y),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..color = _deepRose,
        );
        break;
      case CharacterPose.confused:
        // 一邊高一邊低的波浪嘴
        canvas.drawPath(
          Path()
            ..moveTo(110, y + 4)
            ..cubicTo(116, y - 1, 122, y + 8, 130, y + 1),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.2
            ..strokeCap = StrokeCap.round
            ..color = _deepRose,
        );
        break;
      case CharacterPose.idle:
        canvas.drawPath(
          Path()
            ..moveTo(111, y)
            ..cubicTo(116, y + 8, 124, y + 8, 129, y),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.2
            ..strokeCap = StrokeCap.round
            ..color = _deepRose,
        );
        break;
    }
  }

  // ── 情境部件 ──────────────────────────────────────────────

  /// 敷面膜：白色片狀面膜，挖眼洞與嘴洞，眼睛在洞裡閉著。
  ///
  /// 第一版是綠色泥膜加兩片小黃瓜，配色再怎麼調都偏驚悚——
  /// 整張臉塗成綠的就是恐怖片。白面膜是大家真的在用的東西，
  /// 也接得上她那句「你要不要也來一片」。
  void _sheetMask(Canvas canvas) {
    canvas.save();
    canvas.clipPath(_facePath());

    // 上緣用透明漸層收掉，不要切一條硬邊：
    // 平塗整張臉會從瀏海分線的空隙露出一塊白、像戴了頭盔；
    // 直接切在髮際線又會出現一條水平線，像泡在水裡。
    const sheetRect = Rect.fromLTWH(60, 70, 120, 110);
    canvas.drawRect(
      sheetRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00FBF6F2), Color(0xFFFBF6F2), Color(0xFFEFE3DA)],
          stops: [0.0, 0.34, 1.0],
        ).createShader(sheetRect),
    );

    // 只留下巴下方一道很輕的摺線。
    // 兩側各加一道會變成從眼睛流下來的淚痕，斜向的高光會變成一道裂痕——
    // 為了「看起來是濕的」加的細節，反而是這張圖之前恐怖的來源。
    canvas.drawPath(
      Path()
        ..moveTo(106, 166)
        ..cubicTo(112, 170, 128, 170, 134, 166),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFE0D2CA),
    );

    canvas.restore();

    // 眼洞：露出底下的皮膚，眼睛在裡面閉著
    for (var i = 0; i < 2; i++) {
      final c = _eyeCenters[i];
      final out = i == 0 ? -1.0 : 1.0;
      final hole = Rect.fromCenter(center: c, width: 32, height: 21);

      canvas.drawOval(hole, Paint()..color = _skin);
      canvas.drawOval(
        hole,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFFEADCD4),
      );

      // 閉著的眼：往下彎的弧，末端往外挑一小截睫毛
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - 11 * out, c.dy - 1)
          ..cubicTo(c.dx - 5 * out, c.dy + 7, c.dx + 5 * out, c.dy + 7,
              c.dx + 11 * out, c.dy - 1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = _ink,
      );
      canvas.drawPath(
        Path()
          ..moveTo(c.dx + 11 * out, c.dy - 1)
          ..lineTo(c.dx + 16 * out, c.dy - 5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..color = _ink,
      );
    }

    // 嘴洞。嘴本身由 _mouth 畫在這之後，所以這裡只開洞
    final mouthHole =
        Rect.fromCenter(center: const Offset(120, 154), width: 30, height: 16);
    canvas.drawOval(mouthHole, Paint()..color = _skin);
    canvas.drawOval(
      mouthHole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFEADCD4),
    );
  }

  /// 掃把：以握把為軸心跟著 t 擺動，手畫在軸心上所以不會鬆手
  void _broom(Canvas canvas) {
    canvas.save();
    canvas.translate(_broomGrip.dx, _broomGrip.dy);
    canvas.rotate(-0.1 + (t - 0.5) * 0.2);

    // 握柄
    canvas.drawLine(
      const Offset(0, -80),
      const Offset(0, 26),
      Paint()
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFB0764A),
    );
    canvas.drawLine(
      const Offset(-1.5, -76),
      const Offset(-1.5, 22),
      Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFD29A6C),
    );
    // 束口
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, 30), width: 20, height: 12),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF8C5A38),
    );
    // 鬃毛
    const bristleRect = Rect.fromLTWH(-22, 34, 44, 40);
    canvas.drawPath(
      Path()
        ..moveTo(-10, 34)
        ..lineTo(10, 34)
        ..lineTo(22, 74)
        ..lineTo(-22, 74)
        ..close(),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE0B274), Color(0xFFC08F4C)],
        ).createShader(bristleRect),
    );
    final line = Paint()
      ..strokeWidth = 1.6
      ..color = const Color(0xFFA8783E).withOpacity(0.7);
    for (var i = -3; i <= 3; i++) {
      canvas.drawLine(Offset(i * 3.0, 36), Offset(i * 6.0, 72), line);
    }
    canvas.restore();
  }

  /// 頭上的問號。
  ///
  /// 用 Path 畫而不是 TextPainter 畫 '?'：字型不在自己手上，
  /// 缺字時會變成一個實心方塊（flutter_test 的 Ahem 字型就是這樣，
  /// 裝置上換了 fallback 也可能歪掉）。自己畫的形狀到哪都一樣。
  void _questionMark(Canvas canvas) {
    canvas.save();
    canvas.translate(196, 44);
    canvas.rotate(0.2);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = _deepRose;

    canvas.drawPath(
      Path()
        ..moveTo(-9, -8)
        ..cubicTo(-9, -22, 10, -22, 9, -9)
        ..cubicTo(8, -1, 0, 0, 0, 8),
      stroke,
    );
    canvas.drawCircle(const Offset(0, 18), 3.4, Paint()..color = _deepRose);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WifePainter oldDelegate) =>
      oldDelegate.pose != pose || oldDelegate.t != t;
}
