package com.joechiboo.honey_mishears

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 語言包查詢／下載的橋接（speech_to_text 沒有包這組 API）
        SpeechModelBridge(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }
}
