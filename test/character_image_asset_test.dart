import 'package:flutter_test/flutter_test.dart';
import 'package:honey_mishears/core/character_pose.dart';
import 'package:honey_mishears/ui/widgets/image_character.dart';

/// 這組測試守的是「美術照著檔名放圖」這個契約。
/// 姿勢 enum 一旦改名，已經畫好的 PNG 就對不上了——讓測試先講，
/// 不要等到手機上出現一張退回 idle 的圖才發現。
void main() {
  group('角色圖檔名契約', () {
    test('每個姿勢對應到 assets/character/default 下的同名 PNG', () {
      expect(characterImageAsset(CharacterPose.idle),
          'assets/character/default/idle.png');
      expect(characterImageAsset(CharacterPose.listening),
          'assets/character/default/listening.png');
      expect(characterImageAsset(CharacterPose.clean),
          'assets/character/default/clean.png');
      expect(characterImageAsset(CharacterPose.lottery),
          'assets/character/default/lottery.png');
      expect(characterImageAsset(CharacterPose.mask),
          'assets/character/default/mask.png');
      expect(characterImageAsset(CharacterPose.bundled),
          'assets/character/default/bundled.png');
      expect(characterImageAsset(CharacterPose.confused),
          'assets/character/default/confused.png');
    });

    test('每個姿勢都有自己的檔名，不會兩個姿勢共用一張圖', () {
      final paths = CharacterPose.values.map(characterImageAsset).toSet();
      expect(paths.length, CharacterPose.values.length);
    });
  });
}
