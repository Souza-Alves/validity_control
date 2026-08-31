package com.controlevalidades.controle_validades

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(CameraImageSaverPlugin())
        flutterEngine.plugins.add(EmailSenderPlugin())
    }
}