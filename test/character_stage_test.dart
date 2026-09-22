import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honey_mishears/core/character_pose.dart';
import 'package:honey_mishears/data/mishear_rule.dart';
import 'package:honey_mishears/ui/widgets/character_renderer.dart';
import 'package:honey_mishears/ui/widgets/character_stage.dart';
import 'package:honey_mishears/ui/widgets/image_character.dart';
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
