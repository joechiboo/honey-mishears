package com.joechiboo.honey_mishears

import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.speech.ModelDownloadListener
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * 裝置端語音模型（語言包）的查詢與下載。
 *
 * speech_to_text 套件沒有包這兩支 Android 13(API 33) 才有的 API：
 *   - checkRecognitionSupport()：問清楚哪些語言「已安裝／可下載／下載中」
 *   - triggerModelDownload()   ：直接叫系統去下載（API 34 以上還會回報進度）
 *
 * 少了它們，使用者遇到 error_language_unavailable 只能自己去翻系統設定，
 * 而那個路徑連工程師都不見得找得到。
 *
 * API 33 以下沒有這組 API，只能退回「幫他開啟語音輸入設定頁」。
 */
class SpeechModelBridge(
    private val context: Context,
    messenger: BinaryMessenger,
) {
    companion object {
        private const val METHOD_CHANNEL = "honey_mishears/speech_model"
        private const val EVENT_CHANNEL = "honey_mishears/speech_model_events"
    }

    private var events: EventChannel.EventSink? = null

    init {
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "check" -> check(call.argument<String>("locale") ?: "zh-TW", result)
                "download" -> download(call.argument<String>("locale") ?: "zh-TW", result)
                "openVoiceInputSettings" -> openVoiceInputSettings(result)
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    events = sink
                }

                override fun onCancel(arguments: Any?) {
                    events = null
                }
            },
        )
    }

    /** 組一個「我要用這個語言做辨識」的 intent，兩支 API 都靠它表達語言 */
    private fun recognizeIntent(locale: String) =
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
        }

    /**
     * 查這台裝置對某個語言的支援狀況。
     * 回傳的 supported 清單是「可以下載的」，installed 是「已經可以用的」。
     */
    private fun check(locale: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(
                mapOf(
                    "apiLevel" to Build.VERSION.SDK_INT,
                    "apiAvailable" to false,
                ),
            )
            return
        }

        if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) {
            result.success(
                mapOf(
                    "apiLevel" to Build.VERSION.SDK_INT,
                    "apiAvailable" to true,
                    "onDeviceAvailable" to false,
                ),
            )
            return
        }

        val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
        var replied = false

        recognizer.checkRecognitionSupport(
            recognizeIntent(locale),
            context.mainExecutor,
            object : RecognitionSupportCallback {
                override fun onSupportResult(support: RecognitionSupport) {
                    if (replied) return
                    replied = true
                    result.success(
                        mapOf(
                            "apiLevel" to Build.VERSION.SDK_INT,
                            "apiAvailable" to true,
                            "onDeviceAvailable" to true,
                            "installed" to support.installedOnDeviceLanguages,
                            "pending" to support.pendingOnDeviceLanguages,
                            "supported" to support.supportedOnDeviceLanguages,
                            "online" to support.onlineLanguages,
                        ),
                    )
                    recognizer.destroy()
                }

                override fun onError(error: Int) {
                    if (replied) return
                    replied = true
                    result.success(
                        mapOf(
                            "apiLevel" to Build.VERSION.SDK_INT,
                            "apiAvailable" to true,
                            "onDeviceAvailable" to true,
                            "errorCode" to error,
                        ),
                    )
                    recognizer.destroy()
                }
            },
        )
    }

    /**
     * 叫系統去下載語言包。
     *
     * 這支是非同步而且可能跑很久（模型動輒數十 MB），所以 MethodChannel 只回
     * 「有沒有排程成功」，真正的進度與結果走 EventChannel。
     */
    private fun download(locale: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            !SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        ) {
            result.success(mapOf("scheduled" to false))
            return
        }

        val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
        val intent = recognizeIntent(locale)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // API 34 以上才有進度回報
            recognizer.triggerModelDownload(
                intent,
                context.mainExecutor,
                object : ModelDownloadListener {
                    override fun onProgress(completedPercent: Int) {
                        emit(mapOf("event" to "progress", "percent" to completedPercent))
                    }

                    override fun onScheduled() {
                        emit(mapOf("event" to "scheduled"))
                    }

                    override fun onSuccess() {
                        emit(mapOf("event" to "success"))
                        recognizer.destroy()
                    }

                    override fun onError(error: Int) {
                        emit(mapOf("event" to "error", "code" to error))
                        recognizer.destroy()
                    }
                },
            )
        } else {
            // API 33 只能射後不理，沒有任何回報
            @Suppress("DEPRECATION")
            recognizer.triggerModelDownload(intent)
            emit(mapOf("event" to "scheduled"))
            emit(mapOf("event" to "unknown"))
        }

        result.success(mapOf("scheduled" to true))
    }

    /** 退路：API 太舊或語言不在可下載清單時，至少幫他把設定頁打開 */
    private fun openVoiceInputSettings(result: MethodChannel.Result) {
        val candidates = listOf(
            Intent("android.settings.VOICE_INPUT_SETTINGS"),
            Intent(Settings.ACTION_INPUT_METHOD_SETTINGS),
            Intent(Settings.ACTION_SETTINGS),
        )
        for (intent in candidates) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (intent.resolveActivity(context.packageManager) != null) {
                context.startActivity(intent)
                result.success(true)
                return
            }
        }
        result.success(false)
    }

    private fun emit(payload: Map<String, Any?>) {
        events?.success(payload)
    }
}
