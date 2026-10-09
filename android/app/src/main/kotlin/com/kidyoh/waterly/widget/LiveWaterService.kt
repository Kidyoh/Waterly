package com.kidyoh.waterly.widget

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import com.kidyoh.waterly.R
import kotlin.math.min

/**
 * Brings the widget's water to life for a few seconds after a tap: it
 * follows the phone's tilt, sloshes and pours, then settles back to a
 * still frame.
 *
 * Widgets can't read sensors or animate on their own, so this runs as a
 * short foreground service, which Android allows when started from a
 * widget tap, and pushes a new picture to each widget about 15 times a
 * second.
 */
class LiveWaterService : Service(), SensorEventListener {
    private lateinit var thread: HandlerThread
    private lateinit var handler: Handler
    private lateinit var renderer: WaterRenderer
    private var sensors: SensorManager? = null

    /** Physics per widget id, since each widget has its own size. */
    private val widgets = mutableMapOf<Int, Pair<WidgetKind, WaterPhysics>>()

    private var running = false
    private var liveUntil = 0L
    private var settleUntil = 0L
    private var lastFrame = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        thread = HandlerThread("water-frames").also { it.start() }
        handler = Handler(thread.looper)
        renderer = WaterWidgets.renderer(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startInForeground()
        val action = intent?.action
        val ml = intent?.getIntExtra(WaterWidgets.EXTRA_ML, 0) ?: 0
        handler.post { onTap(action, ml) }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        sensors?.unregisterListener(this)
        thread.quitSafely()
        super.onDestroy()
    }

    /** Android 14+ caps short services at a few minutes; ours never get close. */
    override fun onTimeout(startId: Int) {
        handler.post { finish() }
    }

    private fun onTap(action: String?, ml: Int) {
        val data = WaterData(this)
        if (!running) start(data)
        if (action == WaterWidgets.ACTION_ADD && ml > 0) {
            val goal = data.goal
            val before = data.todayTotal()
            val after = data.add(ml)
            val reached = before < goal && after >= goal
            for ((_, physics) in widgets.values) {
                physics.pourIn(after, goal)
                if (reached) physics.celebrate()
            }
            buzz(reached)
        }
        liveUntil = SystemClock.uptimeMillis() + LIVE_MS
        if (settleUntil != 0L) {
            // Tapped again while settling: wake back up.
            settleUntil = 0L
            listen()
        }
    }

    private fun start(data: WaterData) {
        val total = data.todayTotal()
        val goal = data.goal
        widgets.clear()
        for ((id, kind) in WaterWidgets.all(this)) {
            val (w, h) = WaterWidgets.sizeDp(this, id, kind)
            widgets[id] = kind to WaterPhysics().apply {
                renderer.layout(this, kind, w, h)
                setTotals(total, goal, snap = true)
                scatterBubbles(4)
            }
        }
        running = true
        settleUntil = 0L
        listen()
        lastFrame = SystemClock.uptimeMillis()
        handler.post(frame)
    }

    private fun listen() {
        val manager = sensors ?: (getSystemService(Context.SENSOR_SERVICE) as SensorManager).also { sensors = it }
        manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)?.let {
            manager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME, handler)
        }
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (settleUntil != 0L) return
        for ((_, physics) in widgets.values) physics.setGravity(event.values[0], event.values[1])
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private val frame = object : Runnable {
        override fun run() {
            if (!running) return
            val now = SystemClock.uptimeMillis()
            var dt = (now - lastFrame) / 1000f
            lastFrame = now

            if (settleUntil == 0L && now > liveUntil) {
                // Stop following the phone and let the water drift back to level.
                settleUntil = now + SETTLE_MS
                sensors?.unregisterListener(this@LiveWaterService)
                for ((_, physics) in widgets.values) physics.level()
            }

            val manager = AppWidgetManager.getInstance(this@LiveWaterService)
            for ((id, widget) in widgets) {
                val (kind, physics) = widget
                // Small steps keep the springs stable if a frame runs late.
                var left = dt
                while (left > 0f) {
                    physics.step(min(left, 1f / 30))
                    left -= 1f / 30
                }
                val w = physics.width
                val h = physics.height
                val scale = WaterWidgets.scaleFor(this@LiveWaterService, w, h, WaterWidgets.LIVE_BYTES)
                val bitmap = renderer.render(physics, kind, w, h, scale, WaterWidgets.cornerDp)
                manager.partiallyUpdateAppWidget(
                    id,
                    WaterWidgets.frame(this@LiveWaterService, kind).apply {
                        setImageViewBitmap(R.id.water, bitmap)
                    },
                )
            }

            if (settleUntil != 0L && now > settleUntil) {
                finish()
            } else {
                handler.postDelayed(this, FRAME_MS)
            }
        }
    }

    private fun finish() {
        if (!running) return
        running = false
        sensors?.unregisterListener(this)
        WaterWidgets.refresh(this)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun startInForeground() {
        val manager = getSystemService(NotificationManager::class.java)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Live widget", NotificationManager.IMPORTANCE_MIN).apply {
                    description = "Shown while the widget's water is moving"
                    setShowBadge(false)
                },
            )
            Notification.Builder(this, CHANNEL)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this).setPriority(Notification.PRIORITY_MIN)
        }
        builder
            .setSmallIcon(R.drawable.ic_stat_waterly)
            .setContentTitle("Waterly")
            .setContentText("Moving the water on your widget")
            .setOngoing(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Sessions are shorter than the 10 s Android waits before showing this.
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_DEFERRED)
        }
        val notification = builder.build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SHORT_SERVICE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buzz(strong: Boolean) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        @Suppress("DEPRECATION")
        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
        vibrator.vibrate(
            VibrationEffect.createPredefined(
                if (strong) VibrationEffect.EFFECT_HEAVY_CLICK else VibrationEffect.EFFECT_CLICK,
            ),
        )
    }

    companion object {
        private const val CHANNEL = "live_water"
        private const val NOTIFICATION_ID = 7001

        /** How long the water follows the phone after the last tap. */
        private const val LIVE_MS = 8_000L
        private const val SETTLE_MS = 1_200L
        private const val FRAME_MS = 66L
    }
}
