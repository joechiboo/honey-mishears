# Flutter / Rive / speech_to_text 在 R8 下的保留規則
-keep class io.flutter.** { *; }
-keep class app.rive.** { *; }
-dontwarn app.rive.**

# Play Core 分包 API：Flutter 3.x 的 deferred components 會參照到，
# 沒有引入 play core 時要忽略，否則 R8 會報 missing class
-dontwarn com.google.android.play.core.**
