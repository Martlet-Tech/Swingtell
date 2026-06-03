package com.swingtell.epub_reader

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var ttsHelper: TtsHelper? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ttsHelper = TtsHelper(flutterEngine.dartExecutor.binaryMessenger, this)
        ttsHelper!!.setup()
    }
}
