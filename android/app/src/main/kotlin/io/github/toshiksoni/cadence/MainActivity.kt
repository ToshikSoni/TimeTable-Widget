package io.github.toshiksoni.cadence

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.github.toshiksoni.cadence.dnd.DndScheduler

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "io.github.toshiksoni.cadence/dnd")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasAccess" -> result.success(DndScheduler.hasAccess(this))
                    "requestAccess" -> {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
                        result.success(null)
                    }
                    "schedule" -> {
                        val raw = call.argument<List<List<Number>>>("windows").orEmpty()
                        DndScheduler.schedule(
                            this,
                            raw.filter { it.size == 2 }.map { longArrayOf(it[0].toLong(), it[1].toLong()) },
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
