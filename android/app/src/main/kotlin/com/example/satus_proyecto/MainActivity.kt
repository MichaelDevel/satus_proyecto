package com.example.satus_proyecto

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.satus_proyecto/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "updateWidget") {
                    android.util.Log.d("SatusWidget", "✅ MethodChannel recibido en Kotlin")
                    val intent = Intent("com.example.satus_proyecto.UPDATE_WIDGET")
                    intent.setPackage(packageName)
                    sendBroadcast(intent)
                    android.util.Log.d("SatusWidget", "✅ Broadcast enviado")
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val habitId = intent.getStringExtra("habit_id")
        if (habitId != null) {
            // Enviar el ID a Flutter via MethodChannel
            MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL)
                .invokeMethod("openHabit", habitId)
        }
    }
}