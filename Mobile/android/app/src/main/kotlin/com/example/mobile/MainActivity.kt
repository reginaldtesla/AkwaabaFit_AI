package com.example.mobile

import android.os.Build
import android.os.Bundle
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val splashScreen = installSplashScreen()
            // Dismiss the mandatory Android 12+ splash as soon as possible.
            splashScreen.setKeepOnScreenCondition { false }
        }
        super.onCreate(savedInstanceState)
    }
}
