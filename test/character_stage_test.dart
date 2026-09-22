import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honey_mishears/core/character_pose.dart';
import 'package:honey_mishears/data/mishear_rule.dart';
import 'package:honey_mishears/ui/widgets/character_renderer.dart';
import 'package:honey_mishears/ui/widgets/character_stage.dart';
import 'package:honey_mishears/ui/widgets/image_character.dart';
import 'package:honey_mishears/ui/widgets/painters/bed_painter.dart';
import 'package:honey_mishears/ui/widgets/placeholder_character.dart';

/// 守的是「素材放進去就會生效」這條路。
/// 掃描素材需要真的 asset，測不到；但掃完之後由誰來畫是純邏輯，這裡測得到。
void main() {
  Future<void> pumpStage(WidgetTester tester, CharacterAssets assets) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CharacterStage(
            pose: CharacterPose.idle,
            effect: StageEffect.none,
            assets: assets,
          ),
        ),
      ),
    );
  }

  group('舞台挑渲染器', () {
    testWidgets('沒有任何素材時用佔位角色', (tester) async {
      await pumpStage(tester, CharacterAssets.placeholderOnly);

      expect(find.byType(PlaceholderCharacter), findsOneWidget);
      expect(find.byType(ImageCharacter), findsNothing);
    });

    testWidgets('有圖片素材時改用圖片角色', (tester) async {
      await pumpStage(
        tester,
        const CharacterAssets(
          renderer: CharacterRenderer.image,
          imagePoses: <CharacterPose>{CharacterPose.idle},
        ),
      );

      expect(find.byType(ImageCharacter), findsOneWidget);
    });
  });

  group('設定檔的 animationTrigger 對得到姿勢', () {
    // 新增姿勢時最容易漏掉 characterPoseFromTrigger——漏了不會編譯錯誤，
    // 只會安靜地退回 idle，變成「梗有反應但她沒動」。
    test('每個姿勢的 riveTrigger 都要能反推回自己', () {
      for (final pose in CharacterPose.values) {
        expect(characterPoseFromTrigger(pose.riveTrigger), pose,
            reason: '${pose.name} 的 trigger「${pose.riveTrigger}」對不回來');
      }
    });

    test('沒對到的 trigger 退回 idle', () {
      expect(characterPoseFromTrigger('nonsense'), CharacterPose.idle);
    });
  });

  group('床的遮擋層', () {
    testWidgets('坐在床上時角色畫在床的前後兩層之間', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CharacterStage(
              pose: CharacterPose.sitting,
              effect: StageEffect.bed,
              assets: CharacterAssets.placeholderOnly,
            ),
          ),
        ),
      );

      // 前後兩層都要在。少了 front 那層她就變成站在床前面——
      // 這個姿勢沒有腿，全靠棉被蓋住下半身才讀得出「坐著」。
      final painters = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<BedPainter>()
          .map((p) => p.layer)
          .toList();

      expect(painters, containsAll(<BedLayer>[BedLayer.back, BedLayer.front]));
    });

    testWidgets('其他情境不會冒出床', (tester) async {
      await pumpStage(tester, CharacterAssets.placeholderOnly);

      final beds = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<BedPainter>();

      expect(beds, isEmpty);
    });
  });

  group('圖片角色補圖策略', () {
    test('有圖的姿勢用自己的圖', () {
      expect(characterImageAsset(CharacterPose.clean),
          endsWith('/clean.png'));
    });

    testWidgets('缺圖的姿勢退回 idle，不會去要一張不存在的圖', (tester) async {
      // 只有 idle 有圖，卻要畫 clean
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImageCharacter(
              pose: CharacterPose.clean,
              availablePoses: <CharacterPose>{CharacterPose.idle},
            ),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      final provider = image.image as AssetImage;
      expect(provider.assetName, characterImageAsset(CharacterPose.idle));
    });
  });
}
