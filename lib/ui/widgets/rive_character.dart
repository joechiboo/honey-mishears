import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:rive/rive.dart';

import '../../core/character_pose.dart';

/// Rive 素材路徑與狀態機名稱。
/// 美術完成後把檔案放到這個位置、狀態機取這個名字，程式就會自動接上。
/// 詳細規格見 docs/rive_state_machine.md
const String kRiveAssetPath = 'assets/rive/wife.riv';
const String kRiveStateMachine = 'WifeStateMachine';

/// 檢查 Rive 素材是否已經存在（尚未製作完成時會丟例外 → 回 false）
Future<bool> isRiveAssetAvailable() async {
  try {
    await rootBundle.load(kRiveAssetPath);
    return true;
  } catch (_) {
    return false;
  }
}

/// 真正的 Rive 角色。素材還沒好之前不會被用到（由 CharacterStage 決定）。
class RiveCharacter extends StatefulWidget {
  const RiveCharacter({super.key, required this.pose});

  final CharacterPose pose;

  @override
  State<RiveCharacter> createState() => _RiveCharacterState();
}

class _RiveCharacterState extends State<RiveCharacter> {
  StateMachineController? _controller;

  @override
  void didUpdateWidget(covariant RiveCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 姿勢變了就送一次 trigger 給狀態機
    if (oldWidget.pose != widget.pose) {
      _fire(widget.pose);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onRiveInit(Artboard artboard) {
    final controller =
        StateMachineController.fromArtboard(artboard, kRiveStateMachine);
    if (controller == null) {
      debugPrint('[Rive] 找不到狀態機 $kRiveStateMachine，角色會停在預設動畫');
      return;
    }
    artboard.addController(controller);
    _controller = controller;
    _fire(widget.pose);
  }

  /// 觸發對應的 Trigger；狀態機裡沒有這個 input 時安靜略過，不讓 App 掛掉
  void _fire(CharacterPose pose) {
    final trigger = _controller?.getTriggerInput(pose.riveTrigger);
    if (trigger == null) {
      debugPrint('[Rive] 狀態機缺少 trigger: ${pose.riveTrigger}');
      return;
    }
    trigger.fire();
  }

  @override
  Widget build(BuildContext context) {
    return RiveAnimation.asset(
      kRiveAssetPath,
      stateMachines: const [kRiveStateMachine],
      fit: BoxFit.contain,
      onInit: _onRiveInit,
    );
  }
}
