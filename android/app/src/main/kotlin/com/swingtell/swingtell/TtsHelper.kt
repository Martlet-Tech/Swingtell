package com.swingtell.swingtell

import android.content.Context
import android.content.Intent
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.UUID

/** Minimal native TTS wrapper using the latest Android APIs. */
class TtsHelper(private val messenger: io.flutter.plugin.common.BinaryMessenger, private val context: Context) {
    private val channel = MethodChannel(messenger, "swingtell_tts")
    private var tts: TextToSpeech? = null
    private var isInitialized = false

    fun setup() {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledEngines" -> {
                    try {
                        val engines = mutableListOf<String>()
                        val intent = Intent(TextToSpeech.Engine.INTENT_ACTION_TTS_SERVICE)
                        val packages = context.packageManager.queryIntentServices(intent, 0)
                        for (info in packages) {
                            engines.add(info.serviceInfo.packageName)
                        }
                        result.success(engines)
                    } catch (e: Exception) {
                        result.success(emptyList<String>())
                    }
                }
                "init" -> {
                    val engine = call.argument<String>("engine")
                    initTts(engine, result)
                }
                "speak" -> {
                    val text = call.argument<String>("text") ?: ""
                    speak(text, result)
                }
                "stop" -> {
                    tts?.stop()
                    result.success(true)
                }
                "setSpeechRate" -> {
                    val rate = call.argument<Double>("rate") ?: 0.5
                    tts?.setSpeechRate(rate.toFloat())
                    result.success(true)
                }
                "setPitch" -> {
                    val pitch = call.argument<Double>("pitch") ?: 1.0
                    tts?.setPitch(pitch.toFloat())
                    result.success(true)
                }
                "setLanguage" -> {
                    val lang = call.argument<String>("language") ?: "zh-CN"
                    tts?.language = Locale.forLanguageTag(lang)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun initTts(engine: String?, result: MethodChannel.Result) {
        val listener = TextToSpeech.OnInitListener { status ->
            isInitialized = (status == TextToSpeech.SUCCESS)
            if (isInitialized) {
                tts!!.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String) {
                        channel.invokeMethod("onStart", null)
                    }
                    override fun onDone(utteranceId: String) {
                        channel.invokeMethod("onDone", null)
                    }
                    override fun onError(utteranceId: String) {
                        channel.invokeMethod("onError", "TTS speak error")
                    }
                })
                // Default to Chinese
                tts!!.language = Locale.CHINESE
            }
            result.success(mapOf("success" to isInitialized, "status" to status, "engine" to (engine ?: "default")))
        }

        tts = if (engine != null) {
            TextToSpeech(context, listener, engine)
        } else {
            TextToSpeech(context, listener)
        }
    }

    private fun speak(text: String, result: MethodChannel.Result) {
        if (tts == null || !isInitialized) {
            result.error("TTS_ERR", "TTS not initialized", null)
            return
        }
        val uuid = UUID.randomUUID().toString()
        tts!!.speak(text, TextToSpeech.QUEUE_FLUSH, null, uuid)
        result.success(true)
    }

    fun dispose() {
        tts?.shutdown()
        channel.setMethodCallHandler(null)
    }
}
