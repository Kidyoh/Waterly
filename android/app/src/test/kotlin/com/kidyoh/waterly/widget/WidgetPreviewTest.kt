package com.kidyoh.waterly.widget

import android.content.Context
import android.graphics.Bitmap
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File
import kotlin.random.Random

/**
 * Renders widget frames with Android's real graphics stack to
 * build/widget-previews/, and checks the storage the widget shares with
 * the Flutter app. Run: ./gradlew :app:testDebugUnitTest
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
// A plain Application: Flutter's would try to load the engine.
@Config(sdk = [35], application = android.app.Application::class)
class WidgetPreviewTest {
    private val out = File("build/widget-previews").apply { mkdirs() }
    private val renderer = WaterRenderer(WidgetFonts.fromFile(File("../../assets/fonts/Manrope.ttf")))

    private fun physics(kind: WidgetKind, w: Float, h: Float, total: Int, goal: Int = 2000) =
        WaterPhysics(Random(7)).apply {
            renderer.layout(this, kind, w, h)
            setTotals(total, goal, snap = true)
            time = 3.1f
            scatterBubbles(4)
        }

    private fun save(bitmap: Bitmap, name: String) {
        File(out, name).outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }

    @Test
    fun stillFrames() {
        for ((name, kind, size, total) in listOf(
            Quad("small_57", WidgetKind.SMALL, 160f to 160f, 1150),
            Quad("small_100", WidgetKind.SMALL, 160f to 160f, 2150),
            Quad("medium_57", WidgetKind.MEDIUM, 330f to 160f, 1150),
            Quad("medium_20", WidgetKind.MEDIUM, 330f to 160f, 400),
        )) {
            val (w, h) = size
            save(renderer.render(physics(kind, w, h, total), kind, w, h, 3f, 22f), "$name.png")
        }
        // Widget picker previews.
        save(renderer.render(physics(WidgetKind.SMALL, 160f, 160f, 1150), WidgetKind.SMALL, 160f, 160f, 2.5f, 22f), "widget_preview_small.png")
        val medium = renderer.render(physics(WidgetKind.MEDIUM, 330f, 160f, 1150), WidgetKind.MEDIUM, 330f, 160f, 2.5f, 22f)
        drawCupButtons(medium, 2.5f, 330f, 160f)
        save(medium, "widget_preview_medium.png")
    }

    @Test
    fun liveSession() {
        val (w, h) = 330f to 160f
        val p = physics(WidgetKind.MEDIUM, w, h, 1150)
        // Phone tipped so its right edge is lower, then +250 from the widget.
        p.setGravity(-4f, 9f)
        p.pourIn(1400, 2000)
        var t = 0f
        for (at in listOf(0.25f, 0.6f, 1.2f, 2.5f)) {
            while (t < at) {
                p.step(1f / 30)
                t += 1f / 30
            }
            save(renderer.render(p, WidgetKind.MEDIUM, w, h, 3f, 22f), "live_medium_${(at * 100).toInt()}.png")
        }
        assertTrue("water tilts with the phone", p.surfaceY(w - 10f) < p.surfaceY(10f))
        assertEquals(70, p.percent)

        // Settling back to level once the session ends.
        p.level()
        repeat(240) { p.step(1f / 30) }
        assertTrue(kotlin.math.abs(p.angle) < 0.02f)
        save(renderer.render(p, WidgetKind.MEDIUM, w, h, 3f, 22f), "live_medium_settled.png")
    }

    @Test
    fun sharesStorageWithTheApp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val today = WaterData.dayKey()
        prefs.edit()
            .putLong("flutter.goal", 2500L)
            .putString("flutter.cups", "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu![\"200\",\"330\"]")
            .putString("flutter.entries_$today", "[{\"a\":250,\"t\":1}]")
            .commit()

        val data = WaterData(context)
        assertEquals(2500, data.goal)
        assertEquals(listOf(200, 330), data.cups)
        assertEquals(250, data.todayTotal())
        assertEquals(580, data.add(330))

        // Newest first, as lib/water_store.dart keeps them.
        val saved = prefs.getString("flutter.entries_$today", null)!!
        assertTrue(saved.startsWith("[{\"a\":330"))
        assertEquals(2500L, prefs.getLong("flutter.goal_$today", 0))
    }

    /** The +cup buttons, which are real views on the phone, for the picker preview. */
    private fun drawCupButtons(bitmap: Bitmap, scale: Float, w: Float, h: Float) {
        val c = android.graphics.Canvas(bitmap).apply { scale(scale, scale) }
        val chip = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply { color = 0xCC223A44.toInt() }
        val label = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
            color = android.graphics.Color.WHITE
            textSize = 13f
            typeface = android.graphics.Typeface.create(android.graphics.Typeface.SANS_SERIF, android.graphics.Typeface.BOLD)
            textAlign = android.graphics.Paint.Align.CENTER
        }
        var right = w - 12f
        for (text in listOf("+250", "+150")) {
            val width = label.measureText(text) + 28f
            val rect = android.graphics.RectF(right - width, h - 12f - 36f, right, h - 12f)
            c.drawRoundRect(rect, 18f, 18f, chip)
            c.drawText(text, rect.centerX(), rect.centerY() + 4.5f, label)
            right -= width + 8f
        }
    }

    private data class Quad<A, B, C, D>(val a: A, val b: B, val c: C, val d: D)
}
