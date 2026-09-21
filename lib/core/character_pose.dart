/// 角色的姿勢／動作狀態。
/// 這一層是「App 的狀態」，與 Rive 狀態機的 trigger 名稱一一對應，
/// 佔位角色也用同一組 enum 決定要畫什麼，所以日後換成 Rive 素材時 UI 不用改。
enum CharacterPose {
  /// 待機：呼吸、偶爾眨眼
  idle,

  /// 聆聽中：身體前傾、眼睛睜大
  listening,

  /// 打掃：捲袖子拿掃把
  clean,

  /// 報明牌：戴墨鏡
  lottery,

  /// 歪頭裝傻
  confused,
}

extension CharacterPoseX on CharacterPose {
  /// 送進 Rive 狀態機的 Trigger 名稱
  String get riveTrigger {
    switch (this) {
      case CharacterPose.idle:
        return 'idle';
      case CharacterPose.listening:
        return 'listen';
      case CharacterPose.clean:
        return 'clean';
      case CharacterPose.lottery:
        return 'lottery';
      case CharacterPose.confused:
        return 'confuse';
    }
  }
}

/// 由設定檔裡的 animationTrigger 字串反推姿勢
CharacterPose characterPoseFromTrigger(String trigger) {
  switch (trigger) {
    case 'clean':
      return CharacterPose.clean;
    case 'lottery':
      return CharacterPose.lottery;
    case 'confuse':
      return CharacterPose.confused;
    case 'listen':
      return CharacterPose.listening;
    default:
      return CharacterPose.idle;
  }
}
