import 'package:flutter/material.dart';

/// 她坐著的那張床，只在 [StageEffect.bed] 時出現。
///
/// 分前後兩層是必要的：角色只畫到膝蓋以上、根本沒有腿，
/// 單純把床畫在她身後只會看起來像站在床前面。棉被這層蓋過她的下半身，
/// 「坐在床上」才讀得出來——遮擋本身就是這個姿勢的全部。
///
/// 座標跟 [RoomPainter] 一樣全用畫布比例算，不能寫死像素。
class BedPainter extends CustomPainter {
  const BedPainter({required this.layer});

  final BedLayer layer;

  static const Color _frame = Color(0xFFD8BEA8);
  static const Color _frameDark = Color(0xFFC0A48C);
  static const Color _sheet = Color(0xFFFFFCFA);
  static const Color _quilt = Color(0xFFF7C8D0);
  static const Color _quiltShade = Color(0xFFE6A2B1);
  static const Color _pillow = Color(0xFFF4EDF6);
  static const Color _pillowLine = Color(0xFFDCD2E4);

  /// 床墊上緣，對齊她的臀線——她是坐在這條線上。
  static const double _mattressTop = 0.74;

  /// 棉被上緣。這個高度很挑：蓋到腰就變成「躺在床上要睡了」，
  /// 那是完全不同的畫面（也是完全不同的意思）。
  /// 壓到大腿、讓擺在腿上的兩隻手完整露出來，才讀得出「坐著等你」。
  static const double _quiltTop = 0.88;

  @override
  void paint(Canvas canvas, Size size) {
    switch (layer) {
      case BedLayer.back:
        _headboard(canvas, size);
        _mattress(canvas, size);
        _pillows(canvas, size);
      case BedLayer.front:
        _quiltFront(canvas, size);
    }
  }

  /// 床頭板：她背後那片，順便把她從牆上拉開
  void _headboard(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final board = Rect.fromLTWH(w * 0.14, h * 0.40, w * 0.72, h * 0.34);

    canvas.drawRRect(
      RRect.fromRectAndCorners(
        board,
        topLeft: Radius.circular(w * 0.06),
        topRight: Radius.circular(w * 0.06),
      ),
      Paint()..color = _frame,
    );
    // 內縮一圈的線板，不然床頭會是一塊沒有表情的木板
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        board.deflate(w * 0.035),
        Radius.circular(w * 0.04),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _frameDark.withOpacity(0.55),
    );
  }

  void _mattress(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final top = h * _mattressTop;

    // 床墊與床架一路畫到畫布底，下半截會被棉被那層蓋掉，不必收邊
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, top, w * 0.84, h - top),
        Radius.circular(w * 0.03),
      ),
      Paint()..color = _sheet,
    );
    canvas.drawLine(
      Offset(w * 0.08, top + h * 0.012),
      Offset(w * 0.92, top + h * 0.012),
      Paint()
        ..strokeWidth = 1.4
        ..color = _pillowLine.withOpacity(0.7),
    );
  }

  /// 兩顆枕頭靠在床頭，擺在她兩側——中間要留給她。
  /// 位置要夠外側，不然整顆躲在她身後，等於沒畫。
  void _pillows(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final y = h * _mattressTop - h * 0.05;

    for (final cx in [w * 0.15, w * 0.85]) {
      final rect = Rect.fromCenter(
        center: Offset(cx, y),
        width: w * 0.26,
        height: h * 0.13,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(h * 0.035)),
        Paint()..color = _pillow,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(w * 0.022),
          Radius.circular(h * 0.028),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = _pillowLine,
      );
    }
  }

  /// 棉被。畫在角色之後，上緣那條起伏就是「她的腿在被子底下」的交界
  void _quiltFront(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final top = h * _quiltTop;

    final quilt = Path()
      ..moveTo(w * 0.06, h)
      ..lineTo(w * 0.06, top + h * 0.03)
      // 上緣走一條波浪：中間被她的腿頂高一點，兩側落下去
      ..cubicTo(w * 0.20, top - h * 0.02, w * 0.34, top - h * 0.035, w * 0.5,
          top - h * 0.03)
      ..cubicTo(w * 0.66, top - h * 0.035, w * 0.80, top - h * 0.02, w * 0.94,
          top + h * 0.03)
      ..lineTo(w * 0.94, h)
      ..close();

    canvas.drawPath(
      quilt,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_quilt, _quiltShade],
        ).createShader(Rect.fromLTWH(0, top, w, h - top)),
    );

    // 翻折的被口，讓被子有厚度
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.06, top + h * 0.03)
        ..cubicTo(w * 0.20, top - h * 0.02, w * 0.34, top - h * 0.035, w * 0.5,
            top - h * 0.03)
        ..cubicTo(w * 0.66, top - h * 0.035, w * 0.80, top - h * 0.02, w * 0.94,
            top + h * 0.03),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = _sheet,
    );
  }

  @override
  bool shouldRepaint(covariant BedPainter oldDelegate) =>
      oldDelegate.layer != layer;
}

/// 床的兩層：[back] 畫在角色之前，[front] 畫在角色之後
enum BedLayer { back, front }
