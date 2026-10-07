package com.kidyoh.waterly

import com.kidyoh.waterly.widget.WaterWidgets
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The app asks the home screen widgets to redraw after any change.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "waterly/widget")
            .setMethodCallHandler { call, result ->
                if (call.method == "refresh") {
                    Thread { WaterWidgets.refresh(applicationContext) }.start()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
