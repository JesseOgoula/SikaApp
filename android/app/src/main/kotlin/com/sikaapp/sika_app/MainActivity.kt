package com.sikaapp.sika_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Enregistrer le plugin pour les notifications et SMS
        flutterEngine.plugins.add(SikaNotificationPlugin())
    }
}
