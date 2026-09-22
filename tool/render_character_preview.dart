// 開發工具，不是測試——所以放在 tool/ 而不是 test/，`flutter test` 不會掃到。
//
// 把每個姿勢畫成 PNG，讓人可以實際看過再調座標：
//   flutter test tool/render_character_preview.dart
// 產出：build/character_preview/<pose>.png
//
// 用 flutter_test 是因為 CustomPainter 要有 Flutter 的繪圖環境才畫得出來，
// 純 dart script 跑不了。

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honey_mishears/core/app_theme.dart';
import 'package:honey_mishears/core/character_pose.dart';
import 'package:honey_mishears/data/mishear_rule.dart';
import 'package:honey_mishears/ui/widgets/character_renderer.dart';
import 'package:honey_mishears/ui/widgets/character_stage.dart';
import 'package:honey_mishears/ui/widgets/painters/wife_painter.dart';

const double _scale = 2.0;

void main() {
  testWidgets('把六個姿勢畫成 PNG', (tester) async {
    final outDir = Directory('build/character_preview');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    for (final pose in CharacterPose.values) {
      await tester.pumpWidget(
        MaterialApp(
          // Center 是必要的：home 給的是 tight constraints，
          // 不先鬆開的話 SizedBox 的尺寸會被忽略、畫布變成整個視窗大小
          home: Center(
            child: RepaintBoundary(
              key: ValueKey(pose),
              child: SizedBox(
                width: WifePainter.designWidth,
                height: WifePainter.designHeight,
                // 對著 App 的實際底色畫，才看得出邊緣有沒有問題
                child: ColoredBox(
                  color: AppTheme.cream,
                  child: CustomPaint(
                    painter: WifePainter(pose: pose, t: 0.5),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(ValueKey(pose)),
      );
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: _scale);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      });

      File('${outDir.path}/${pose.name}.png').writeAsBytesSync(bytes!);
      debugPrint('寫出 ${pose.name}.png');
    }
  });

  // 角色單獨看起來對、擺進房間卻不對是常有的事（被家具卡到、跟牆同色），
  // 所以整個舞台也要輸出一份。尺寸取手機上那塊區域的實際大小。
  testWidgets('把整個舞台畫成 PNG', (tester) async {
    final outDir = Directory('build/character_preview');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    const cases = {
      'stage_idle': (CharacterPose.idle, StageEffect.none),
      'stage_clean': (CharacterPose.clean, StageEffect.dust),
    };

    for (final entry in cases.entries) {
      final (pose, effect) = entry.value;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: ValueKey(entry.key),
              child: SizedBox(
                width: 360,
                height: 400,
                child: DecoratedBox(
                  decoration:
                      const BoxDecoration(gradient: AppTheme.backgroundGradient),
                  child: CharacterStage(
                    pose: pose,
                    effect: effect,
                    assets: CharacterAssets.placeholderOnly,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(ValueKey(entry.key)),
      );
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: _scale);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      });

      File('${outDir.path}/${entry.key}.png').writeAsBytesSync(bytes!);
      debugPrint('寫出 ${entry.key}.png');
    }
  });
}
