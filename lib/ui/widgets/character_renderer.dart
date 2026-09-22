import '../../core/character_pose.dart';
import 'image_character.dart';
import 'rive_character.dart';

/// 誰來畫這個角色。
///
/// 優先序：Rive（會動、最完整）→ 圖片（好看但不會動）→ 佔位角色（永遠可用的保底）。
/// 三者吃同一組 [CharacterPose]，所以換素材不必動 UI 以外的任何程式。
enum CharacterRenderer { placeholder, image, rive }

/// 啟動時掃一次素材，決定用哪個渲染器、以及圖片素材補到哪了。
class CharacterAssets {
  const CharacterAssets({required this.renderer, required this.imagePoses});

  final CharacterRenderer renderer;

  /// 已經有圖的姿勢；[renderer] 不是 image 時為空集合
  final Set<CharacterPose> imagePoses;

  /// 還沒掃描完之前的預設值（也是素材全缺時的結果）
  static const CharacterAssets placeholderOnly = CharacterAssets(
    renderer: CharacterRenderer.placeholder,
    imagePoses: <CharacterPose>{},
  );
}

/// 掃描素材。放在 App 啟動流程做一次就好，不要每次 build 都掃。
Future<CharacterAssets> resolveCharacterAssets() async {
  if (await isRiveAssetAvailable()) {
    return const CharacterAssets(
      renderer: CharacterRenderer.rive,
      imagePoses: <CharacterPose>{},
    );
  }

  final poses = await availableCharacterImages();
  // 連 idle 都沒有就別走圖片路線了，不然每個姿勢都會退回一張不存在的圖
  if (poses.contains(CharacterPose.idle)) {
    return CharacterAssets(
      renderer: CharacterRenderer.image,
      imagePoses: poses,
    );
  }

  return CharacterAssets.placeholderOnly;
}
