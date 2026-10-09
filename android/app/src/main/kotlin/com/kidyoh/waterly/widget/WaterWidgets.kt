package com.kidyoh.waterly.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.widget.RemoteViews
import com.kidyoh.waterly.MainActivity
import com.kidyoh.waterly.R
import kotlin.math.min
import kotlin.math.sqrt
import kotlin.random.Random

abstract class WaterWidgetProvider(private val kind: WidgetKind) : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        WaterWidgets.refresh(context, ids.map { it to kind })
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        WaterWidgets.refresh(context, listOf(id to kind))
    }
}

/** 2×2: the water and today's %. Tap to wake the water. */
class SmallWaterWidget : WaterWidgetProvider(WidgetKind.SMALL)

/** 4×2: the water plus buttons for both cup sizes. */
class MediumWaterWidget : WaterWidgetProvider(WidgetKind.MEDIUM)

object WaterWidgets {
    const val ACTION_WAKE = "com.kidyoh.waterly.widget.WAKE"
    const val ACTION_ADD = "com.kidyoh.waterly.widget.ADD"
    const val EXTRA_ML = "ml"

    /** Widget bitmaps travel over a ~1 MB binder buffer; stay well under it. */
    private const val STILL_BYTES = 650_000f
    const val LIVE_BYTES = 360_000f

    /** Android 12+ clips widgets to the system's rounded corners itself. */
    val cornerDp: Float
        get() = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) 0f else 22f

    private var fonts: WidgetFonts? = null

    fun renderer(context: Context) =
        WaterRenderer(fonts ?: WidgetFonts.fromAssets(context.assets).also { fonts = it })

    fun all(context: Context): List<Pair<Int, WidgetKind>> {
        val manager = AppWidgetManager.getInstance(context)
        fun ids(cls: Class<*>) = manager.getAppWidgetIds(ComponentName(context, cls)).toList()
        return ids(SmallWaterWidget::class.java).map { it to WidgetKind.SMALL } +
            ids(MediumWaterWidget::class.java).map { it to WidgetKind.MEDIUM }
    }

    /** The widget's size in dp, as laid out in portrait. */
    fun sizeDp(context: Context, id: Int, kind: WidgetKind): Pair<Float, Float> {
        val options = AppWidgetManager.getInstance(context).getAppWidgetOptions(id)
        val w = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val h = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
        return if (w > 0 && h > 0) w.toFloat() to h.toFloat()
        else if (kind == WidgetKind.SMALL) 160f to 160f else 330f to 160f
    }

    /** Pixels per dp: the screen's density, lowered if the bitmap would be too big. */
    fun scaleFor(context: Context, w: Float, h: Float, maxBytes: Float): Float =
        min(context.resources.displayMetrics.density, sqrt(maxBytes / (4f * w * h)))

    /** Sends still frames of today's water to [widgets] (all of them by default). */
    fun refresh(context: Context, widgets: List<Pair<Int, WidgetKind>> = all(context)) {
        if (widgets.isEmpty()) return
        val data = WaterData(context)
        val total = data.todayTotal()
        val goal = data.goal
        val cups = data.cups
        val renderer = renderer(context)
        val manager = AppWidgetManager.getInstance(context)
        for ((id, kind) in widgets) {
            val (w, h) = sizeDp(context, id, kind)
            val physics = WaterPhysics(Random(id)).apply {
                renderer.layout(this, kind, w, h)
                setTotals(total, goal, snap = true)
                time = (System.currentTimeMillis() % 100_000) / 1000f
                scatterBubbles(4)
            }
            val bitmap = renderer.render(physics, kind, w, h, scaleFor(context, w, h, STILL_BYTES), cornerDp)
            manager.updateAppWidget(id, views(context, kind, cups).apply {
                setImageViewBitmap(R.id.water, bitmap)
            })
        }
    }

    /** Only the picture, for live frames sent with partiallyUpdateAppWidget. */
    fun frame(context: Context, kind: WidgetKind) = RemoteViews(context.packageName, layout(kind))

    private fun layout(kind: WidgetKind) =
        if (kind == WidgetKind.SMALL) R.layout.widget_small else R.layout.widget_medium

    private fun views(context: Context, kind: WidgetKind, cups: List<Int>) =
        RemoteViews(context.packageName, layout(kind)).apply {
            setOnClickPendingIntent(R.id.water, serviceIntent(context, 1, ACTION_WAKE, 0))
            setOnClickPendingIntent(R.id.open, openApp(context))
            if (kind == WidgetKind.MEDIUM) {
                setTextViewText(R.id.add_first, "+${cups[0]}")
                setTextViewText(R.id.add_second, "+${cups[1]}")
                setOnClickPendingIntent(R.id.add_first, serviceIntent(context, 2, ACTION_ADD, cups[0]))
                setOnClickPendingIntent(R.id.add_second, serviceIntent(context, 3, ACTION_ADD, cups[1]))
            }
        }

    private fun serviceIntent(context: Context, request: Int, action: String, ml: Int): PendingIntent {
        val intent = Intent(context, LiveWaterService::class.java).setAction(action).putExtra(EXTRA_ML, ml)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            PendingIntent.getForegroundService(context, request, intent, flags)
        } else {
            PendingIntent.getService(context, request, intent, flags)
        }
    }

    private fun openApp(context: Context): PendingIntent = PendingIntent.getActivity(
        context,
        0,
        Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}
