package com.kidyoh.waterly.widget

import android.content.res.AssetManager
import android.graphics.Bitmap
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.os.Build
import java.io.File
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/** Manrope at the weights the widget uses. */
class WidgetFonts(val medium: Typeface, val semiBold: Typeface) {
    companion object {
        private const val ASSET = "flutter_assets/assets/fonts/Manrope.ttf"

        fun fromAssets(assets: AssetManager): WidgetFonts = load(
            { w -> Typeface.Builder(assets, ASSET).setFontVariationSettings("'wght' $w").build() },
        )

        fun fromFile(file: File): WidgetFonts = load(
            { w -> Typeface.Builder(file).setFontVariationSettings("'wght' $w").build() },
        )

        private fun load(build: (Int) -> Typeface?): WidgetFonts {
            // Variable font weights need API 26; older phones get the system font.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val medium = runCatching { build(500) }.getOrNull()
                val semiBold = runCatching { build(650) }.getOrNull()
                if (medium != null && semiBold != null) return WidgetFonts(medium, semiBold)
            }
            return WidgetFonts(
                Typeface.create(Typeface.SANS_SERIF, Typeface.NORMAL),
                Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD),
            )
        }
    }
}

enum class WidgetKind { SMALL, MEDIUM }

/**
 * Draws a widget frame like the app's WaterPainter: background and light
 * rays, the water along gravity with a glowing surface, bubbles, and text
 * that wobbles where the water covers it.
 */
class WaterRenderer(private val fonts: WidgetFonts) {

    /** Positions the water range for a widget of this kind and size (dp). */
    fun layout(p: WaterPhysics, kind: WidgetKind, w: Float, h: Float) {
        val top = if (kind == WidgetKind.SMALL) h * 0.10f else h * 0.08f
        p.layout(w, h, top, h + 2f)
    }

    /**
     * Renders [p] into a new bitmap of [w]×[h] dp at [scale] px per dp.
     * [cornerDp] rounds the corners for launchers that don't clip widgets.
     */
    fun render(p: WaterPhysics, kind: WidgetKind, w: Float, h: Float, scale: Float, cornerDp: Float): Bitmap {
        val bitmap = Bitmap.createBitmap(
            max(1, (w * scale).toInt()),
            max(1, (h * scale).toInt()),
            Bitmap.Config.ARGB_8888,
        )
        val c = Canvas(bitmap)
        c.scale(scale, scale)
        if (cornerDp > 0) c.saveLayer(0f, 0f, w, h, null)

        drawBackground(c, w, h, scale)

        // Surface polyline, and the regions below (water) and above (air) it.
        val xs = generateSequence(-6f) { it + 4f }.takeWhile { it <= w + 6f }.toList()
        val ys = xs.map { p.surfaceY(it).coerceIn(-6f, h + 6f) }
        val surface = Path().apply {
            moveTo(xs[0], ys[0])
            for (i in 1 until xs.size) lineTo(xs[i], ys[i])
        }
        val water = Path(surface).apply {
            lineTo(w + 6f, h + 6f); lineTo(-6f, h + 6f); close()
        }
        val air = Path(surface).apply {
            lineTo(w + 6f, -6f); lineTo(-6f, -6f); close()
        }
        val waterTop = ys.min()

        val lines = textLines(p, kind, w, h)
        for (line in lines) drawAbove(c, line, air, waterTop)
        drawWater(c, p, w, h, surface, water, scale)
        for (line in lines) drawBelow(c, line, water, waterTop, p.time)
        drawBubbles(c, p, water)

        if (cornerDp > 0) {
            c.drawRoundRect(
                RectF(0f, 0f, w, h), cornerDp, cornerDp,
                Paint(Paint.ANTI_ALIAS_FLAG).apply { xfermode = PorterDuffXfermode(PorterDuff.Mode.DST_IN) },
            )
            c.restore()
        }
        return bitmap
    }

    private fun drawBackground(c: Canvas, w: Float, h: Float, scale: Float) {
        c.drawRect(0f, 0f, w, h, Paint().apply {
            shader = LinearGradient(
                0f, 0f, 0f, h,
                intArrayOf(BG_TOP, BG_MID, BG_BOTTOM), floatArrayOf(0f, 0.55f, 1f),
                Shader.TileMode.CLAMP,
            )
        })
        // Soft diagonal light shafts.
        for (i in 0 until 2) {
            val bw = w * (0.16f + 0.08f * i)
            c.save()
            c.translate(w * (0.25f + 0.5f * i), -h * 0.1f)
            c.rotate(28f)
            c.drawRect(-bw / 2, 0f, bw / 2, h * 1.6f, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = LinearGradient(
                    0f, 0f, 0f, h * 1.4f,
                    intArrayOf(white(0.06f), white(0.02f), white(0f)), floatArrayOf(0f, 0.45f, 1f),
                    Shader.TileMode.CLAMP,
                )
                maskFilter = BlurMaskFilter(14f * scale, BlurMaskFilter.Blur.NORMAL)
            })
            c.restore()
        }
    }

    private fun drawWater(c: Canvas, p: WaterPhysics, w: Float, h: Float, surface: Path, water: Path, scale: Float) {
        // Shade along gravity so the gradient tilts with the surface.
        val dx = -sin(p.angle)
        val dy = cos(p.angle)
        val x0 = w / 2 - dx * 14f
        val y0 = p.baseY - dy * 14f
        val depth = max(h - p.baseY + 60f, 120f)
        c.drawPath(water, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                x0, y0, x0 + dx * depth, y0 + dy * depth,
                intArrayOf(
                    withAlpha(WATER_SURFACE, 0.95f),
                    withAlpha(WATER_BODY, 0.82f),
                    withAlpha(WATER_BODY, 0.72f),
                    withAlpha(WATER_DEEP, 0.9f),
                ),
                floatArrayOf(0f, 0.08f, 0.4f, 1f),
                Shader.TileMode.CLAMP,
            )
        })
        c.save()
        c.clipPath(water)
        c.drawPath(surface, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 18f
            color = withAlpha(FOAM, 0.35f)
            maskFilter = BlurMaskFilter(9f * scale, BlurMaskFilter.Blur.NORMAL)
        })
        c.drawPath(surface, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 1.2f
            color = white(0.55f)
        })
        c.restore()
    }

    private fun drawBubbles(c: Canvas, p: WaterPhysics, water: Path) {
        if (p.bubbles.isEmpty()) return
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = white(0.10f) }
        val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE; strokeWidth = 0.8f; color = white(0.5f)
        }
        val shine = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = white(0.7f) }
        c.save()
        c.clipPath(water)
        for (b in p.bubbles) {
            c.drawCircle(b.x, b.y, b.radius, fill)
            c.drawCircle(b.x, b.y, b.radius, ring)
            c.drawCircle(b.x - b.radius * 0.35f, b.y - b.radius * 0.35f, b.radius * 0.28f, shine)
        }
        c.restore()
    }

    // --- Text -------------------------------------------------------------

    /** A line of text made of bright and dim runs, e.g. "1,150" + " / 2,000 ml". */
    private class TextLine(val x: Float, val top: Float, val size: Float, val runs: List<Pair<String, Boolean>>, val typeface: Typeface, val tracking: Float)

    private fun textLines(p: WaterPhysics, kind: WidgetKind, w: Float, h: Float): List<TextLine> {
        val pad = if (kind == WidgetKind.SMALL) 14f else 16f
        val pctSize = if (kind == WidgetKind.SMALL) min(w, h) * 0.30f else min(h * 0.36f, w * 0.2f)
        val shown = formatMl(p.shownMl.toInt())
        val goal = formatMl(p.goal)
        val titleTop = pad
        val pctTop = titleTop + 15f
        val subTop = pctTop + pctSize * 1.08f
        return listOf(
            TextLine(pad, titleTop, 13f, listOf("Water" to true), fonts.semiBold, 0f),
            TextLine(pad - pctSize * 0.04f, pctTop, pctSize, listOf("${p.percent}%" to true), fonts.medium, -0.04f),
            TextLine(pad, subTop, 11.5f, listOf(shown to true, " / $goal ml" to false), fonts.semiBold, 0f),
        )
    }

    private fun paint(line: TextLine, color: Int) = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = line.typeface
        textSize = line.size
        letterSpacing = line.tracking
        this.color = color
    }

    /** Draws each run of [line] at [dx], coloured by [colorOf]. */
    private fun drawRuns(c: Canvas, line: TextLine, dx: Float, colorOf: (Boolean) -> Int) {
        var x = line.x + dx
        val baseline = line.top - paint(line, 0).fontMetrics.ascent
        for ((text, bright) in line.runs) {
            val paint = paint(line, colorOf(bright))
            c.drawText(text, x, baseline, paint)
            x += paint.measureText(text)
        }
    }

    private fun bounds(line: TextLine): RectF {
        val fm = paint(line, 0).fontMetrics
        val width = line.runs.sumOf { paint(line, 0).measureText(it.first).toDouble() }.toFloat()
        return RectF(line.x, line.top, line.x + width, line.top - fm.ascent + fm.descent)
    }

    private fun drawAbove(c: Canvas, line: TextLine, air: Path, waterTop: Float) {
        val colorOf = { bright: Boolean -> if (bright) Color.WHITE else white(0.45f) }
        if (bounds(line).bottom < waterTop) {
            drawRuns(c, line, 0f, colorOf)
            return
        }
        c.save()
        c.clipPath(air)
        drawRuns(c, line, 0f, colorOf)
        c.restore()
    }

    /** The submerged part, in thin strips shifted by a moving wave with a colour fringe. */
    private fun drawBelow(c: Canvas, line: TextLine, water: Path, waterTop: Float, t: Float) {
        val r = bounds(line)
        if (r.bottom < waterTop) return
        val strip = 1.2f
        c.save()
        c.clipPath(water)
        var y = max(r.top - 2f, waterTop - strip)
        while (y < r.bottom + 2f) {
            // Gentler than the app's: widget text is small and must stay readable.
            val dx = sin(y * 0.09f + t * 2.4f) * 1.4f + sin(y * 0.2f - t * 1.5f) * 0.5f
            c.save()
            c.clipRect(r.left - 16f, y, r.right + 16f, y + strip + 0.4f)
            drawRuns(c, line, dx + 0.7f) { b -> withAlpha(PINK, if (b) 0.5f else 0.22f) }
            drawRuns(c, line, dx - 0.7f) { b -> withAlpha(CYAN, if (b) 0.5f else 0.22f) }
            drawRuns(c, line, dx) { b -> if (b) UNDER_BRIGHT else withAlpha(UNDER_DIM, 0.6f) }
            c.restore()
            y += strip
        }
        c.restore()
    }

    companion object {
        // Colours from lib/theme.dart.
        const val BG_TOP = 0xFF0B3646.toInt()
        const val BG_MID = 0xFF125466.toInt()
        const val BG_BOTTOM = 0xFF1B6F7F.toInt()
        private const val WATER_SURFACE = 0xFF5BC3CC.toInt()
        private const val WATER_BODY = 0xFF2B95A3.toInt()
        private const val WATER_DEEP = 0xFF16606F.toInt()
        private const val FOAM = 0xFF8FE3E8.toInt()
        private const val PINK = 0xFFFF8FC8.toInt()
        private const val CYAN = 0xFF6CF6FF.toInt()
        private const val UNDER_BRIGHT = 0xFFF4FEFF.toInt()
        private const val UNDER_DIM = 0xFFD5F6F8.toInt()

        private fun withAlpha(color: Int, alpha: Float) =
            (color and 0x00FFFFFF) or ((alpha * 255).toInt().coerceIn(0, 255) shl 24)

        private fun white(alpha: Float) = withAlpha(Color.WHITE, alpha)

        /** 1150 -> "1,150" */
        fun formatMl(ml: Int): String = "%,d".format(java.util.Locale.US, ml)
    }
}
