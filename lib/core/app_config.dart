/// 全域常數設定
class AppConfig {
  AppConfig._();

  /// App 顯示名稱
  static const String appName = 'AI 老婆';

  /// 語音辨識偏好語系（BCP-47）。
  /// 實際送給辨識器的字串會改用裝置自己的寫法（例如 cmn-Hant-TW），
  /// 見 SpeechService._resolveLocaleId。
  static const String preferredLocale = 'zh-TW';

  /// 是否強制只用「裝置端離線辨識」。
  ///
  /// true  = 完全不連網，但使用者必須事先在系統設定裡下載中文離線語音包，
  ///         沒下載的機器會直接辨識失敗。
  /// false = 交給系統決定（多數 Android 會走 Google 線上辨識）。
  ///
  /// MVP 階段預設 false 以確保流程跑得通；要主打「全離線」時改成 true，
  /// 並在首次啟動引導使用者下載語音包。
  static const bool forceOnDeviceRecognition = false;

  /// 單次收音的最長時間
  static const Duration maxListenDuration = Duration(seconds: 8);

  /// 靜音多久視為講完
  static const Duration pauseDuration = Duration(seconds: 3);

  /// 放開按鈕後，最多再等多久拿最終辨識結果
  static const Duration finalResultTimeout = Duration(milliseconds: 2500);
}
