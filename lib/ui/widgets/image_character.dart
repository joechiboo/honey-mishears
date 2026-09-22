import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;

import '../../core/character_pose.dart';
import 'character_motion.dart';
import 'placeholder_character.dart';

/// 圖片角色素材的資料夾。日後做捏人時，這裡會變成 assets/character/<styleId>/。
const String kCharacterImageDir = 'assets/character/default';

/// 檔名契約：一個姿勢一張同名的去背 PNG。
/// 例如 [CharacterPose.clean] → `assets/character/default/clean.png`
String characterImageAsset(CharacterPose pose) =>
    '$kCharacterImageDir/${pose.name}.png';

/// 掃一次 asset manifest，回報哪些姿勢已經有圖。
///
/// 用 manifest 而不是逐張 `rootBundle.load`，是因為後者會把整張 PNG 的
/// bytes 讀進來並留在 cache 裡，只為了問一句「在不在」太貴。
/// 一張都沒有時回空集合 → 外層會退回佔位角色。
Future<Set<CharacterPose>> availableCharacterImages() async {
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets().toSet();
    return CharacterPose.values
        .where((pose) => assets.contains(characterImageAsset(pose)))
        .toSet();
  } catch (error) {
    debugPrint('[Character] 讀不到 asset manifest：$error');
    return <CharacterPose>{};
  }
}

/// 圖片角色：一個姿勢一張去背 PNG。
///
/// 缺圖的姿勢會退回 `idle.png`，所以素材可以一張一張補，不必一次到齊。
class ImageCharacter extends StatelessWidget {
  const ImageCharacter({
    super.key,
    required this.pose,
    required this.availablePoses,
  });

  final CharacterPose pose;

  /// 由 [availableCharacterImages] 算出來的「這些姿勢有圖」
  final Set<CharacterPose> availablePoses;

  @override
  Widget build(BuildContext context) {
    final shown =
        availablePoses.contains(pose) ? pose : CharacterPose.idle;

    return CharacterMotion(
      pose: pose,
      builder: (context, t) => Image.asset(
        characterImageAsset(shown),
        width: 260,
        height: 300,
        fit: BoxFit.contain,
        // manifest 說有、實際卻解不開（檔案壞了）時的保底。
        // 這條路上佔位角色自己也會再套一層 CharacterMotion，歪頭會比平常誇張，
        // 但總比整個畫面炸掉好——而且正常情況根本走不到這裡。
        errorBuilder: (context, error, stack) {
          debugPrint('[Character] 圖片載入失敗：${characterImageAsset(shown)} $error');
          return PlaceholderCharacter(pose: pose);
        },
      ),
    );
  }
}
