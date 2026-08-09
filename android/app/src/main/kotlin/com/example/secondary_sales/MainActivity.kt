package com.example.secondary_sales

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "secondary_sales/app_update"

        /**
         * Candidate applicationIds for the Firebase App Tester app.
         *
         * App Tester has shipped under more than one id, so each is tried in
         * turn rather than pinning a single guess. Any id listed here must also
         * appear in the manifest's <queries> block, or the lookup returns null
         * on Android 11+ even when the app is installed.
         */
        private val APP_TESTER_PACKAGES = listOf(
            "dev.firebase.appdistribution.apptester",
            "com.google.firebase.appdistribution.apptester",
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Returns false rather than failing when App Tester is
                    // absent, so Dart can fall back to the invite link.
                    "openAppTester" -> result.success(openAppTester())
                    else -> result.notImplemented()
                }
            }
    }

    private fun openAppTester(): Boolean {
        for (packageName in APP_TESTER_PACKAGES) {
            val intent = packageManager.getLaunchIntentForPackage(packageName) ?: continue
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            return true
        }
        return false
    }
}
