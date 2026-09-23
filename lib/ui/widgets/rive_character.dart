import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:rive/rive.dart' as rive;

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
///
/// ⚠️ **這支程式沒有被實際跑過。** 專案裡還沒有 wife.riv，
/// 所以 resolveCharacterAssets() 永遠不會選到它。等真的有素材那天，
/// 第一次跑一定要對著 docs/rive_state_machine.md 的命名契約逐項驗，
/// 特別是狀態機名稱與六個 trigger 的拼字。
class RiveCharacter extends StatefulWidget {
  const RiveCharacter({super.key, required this.pose});

  final CharacterPose pose;

  @override
  State<RiveCharacter> createState() => _RiveCharacterState();
}

class _RiveCharacterState extends State<RiveCharacter> {
  rive.File? _file;
  rive.RiveWidgetController? _controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final file = await rive.File.asset(
        kRiveAssetPath,
        riveFactory: rive.Factory.rive,
      );
      if (file == null) {
        debugPrint('[Rive] 讀不到 $kRiveAssetPath');
        return;
      }
      final controller = rive.RiveWidgetController(
        file,
        stateMachineSelector:
            const rive.StateMachineNamed(kRiveStateMachine),
      );
      if (!mounted) {
        controller.dispose();
        file.dispose();
        return;
      }
      setState(() {
        _file = file;
        _controller = controller;
      });
      _fire(widget.pose);
    } catch (error) {
      // 狀態機名字不對、檔案損壞都會走到這裡。
      // 角色畫不出來不該讓整個 App 掛掉——外層還有佔位角色可以頂。
      debugPrint('[Rive] 載入失敗：$error');
    }
  }

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
    _file?.dispose();
    super.dispose();
  }

  /// 觸發對應的 Trigger；狀態機裡沒有這個 input 時安靜略過，不讓 App 掛掉
  void _fire(CharacterPose pose) {
    final stateMachine = _controller?.stateMachine;
    if (stateMachine == null) return;

    final trigger = stateMachine.trigger(pose.riveTrigger);
    if (trigger == null) {
      debugPrint('[Rive] 狀態機缺少 trigger: ${pose.riveTrigger}');
      return;
    }
    trigger.fire();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    // 載入是非同步的，還沒好之前先讓位置空著——
    // 這裡不畫佔位角色，免得跟外層的保底疊成兩個人
    if (controller == null) return const SizedBox.shrink();

    return rive.RiveWidget(controller: controller);
  }
}
