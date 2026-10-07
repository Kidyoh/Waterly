package com.kidyoh.waterly.widget

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.exp
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.math.tan
import kotlin.random.Random

/**
 * The app's water physics (lib/water_sim.dart), ported for home screen
 * widgets: fill level, tilt against gravity, sloshing waves, ripples and
 * bubbles. Units are dp, with amplitudes tuned for widget sizes.
 */
class WaterPhysics(private val random: Random = Random.Default) {
    class Bubble(var x: Float, var y: Float, val radius: Float, val speed: Float, val phase: Float)
    class Ripple(val x: Float, val strength: Float) {
        var age = 0f
    }

    var width = 0f
    var height = 0f

    /** Y of the surface at 100% and at 0%. */
    var levelTop = 0f
    var levelBottom = 0f

    var time = 0f
    var level = 0f
    private var levelVel = 0f
    private var targetLevel = 0f

    var angle = 0f
    private var angleVel = 0f
    private var targetAngle = 0f

    var slosh = 0f
    var shownMl = 0f
    private var targetMl = 0f
    var goal = 2000

    private var pour = 0f
    private var pourX = 0f
    private var bubbleClock = 0f
    private var rippleClock = 0f
    private var ambientClock = 0f

    val bubbles = mutableListOf<Bubble>()
    val ripples = mutableListOf<Ripple>()

    fun layout(width: Float, height: Float, levelTop: Float, levelBottom: Float) {
        this.width = width
        this.height = height
        this.levelTop = levelTop
        this.levelBottom = levelBottom
    }

    val baseY: Float
        get() = levelBottom + (levelTop - levelBottom) * level.coerceIn(-0.05f, 1.08f)

    val percent: Int
        get() = if (goal <= 0) 0 else floor(shownMl / goal * 100).toInt().coerceIn(0, 100)

    fun surfaceY(x: Float): Float {
        if (width == 0f) return 0f
        val k = 2 * PI.toFloat() / width
        val amp = 2.5f + slosh * 12f
        var y = sin(x * k * 1.2f + time * 1.6f) * 0.55f +
            sin(x * k * 2.7f - time * 2.3f) * 0.30f +
            sin(x * k * 5.1f + time * 3.7f) * 0.15f
        y *= amp
        for (r in ripples) {
            val d = abs(x - r.x)
            y += r.strength * exp(-r.age * 1.8f) * sin(d * 0.07f - r.age * 9f) * exp(-d / 110f)
        }
        return baseY + tan(angle) * (x - width / 2) + y
    }

    /** Sets totals; with [snap] the water and counter jump there at once. */
    fun setTotals(totalMl: Int, goal: Int, snap: Boolean = false) {
        this.goal = goal
        targetMl = totalMl.toFloat()
        targetLevel = if (goal <= 0) 0f else min(totalMl.toFloat() / goal, 1.08f)
        if (snap) {
            level = targetLevel
            levelVel = 0f
            shownMl = targetMl
        }
    }

    fun pourIn(totalMl: Int, goal: Int) {
        setTotals(totalMl, goal)
        pour = POUR_DURATION
        pourX = width * (0.26f + random.nextFloat() * 0.12f)
        slosh = min(slosh + 0.25f, 1.2f)
        ripples += Ripple(pourX, 6f)
    }

    fun celebrate() {
        levelVel += 0.35f
        slosh = 1.2f
        for (i in 0 until 5) ripples += Ripple(width * (0.1f + i * 0.2f), 7f)
        repeat(40) { spawnBubble(random.nextFloat() * width, 12f, 300f) }
    }

    /** Accelerometer reading in device axes (m/s², gravity reaction). */
    fun setGravity(ax: Float, ay: Float) {
        // Lying flat: the roll is undefined, keep the last one.
        if (sqrt(ax * ax + ay * ay) < 2.5f) return
        targetAngle = atan2(ax, ay).coerceIn(-1.25f, 1.25f)
    }

    /** Lets the water drift back to level, e.g. when the live session ends. */
    fun level() {
        targetAngle = 0f
    }

    /** A few resting bubbles so a still frame doesn't look empty. */
    fun scatterBubbles(count: Int) {
        repeat(count) { spawnBubble(random.nextFloat() * width, 14f, 200f) }
    }

    fun step(dtIn: Float) {
        if (width == 0f) return
        val dt = dtIn.coerceIn(0f, 1f / 20)
        time += dt

        levelVel += ((targetLevel - level) * 14f - levelVel * 5f) * dt
        level += levelVel * dt

        val angleAcc = (targetAngle - angle) * 26f - angleVel * 2.6f
        angleVel += angleAcc * dt
        angle += angleVel * dt

        slosh += (abs(angleAcc) * 0.06f + abs(levelVel) * 0.8f) * dt
        slosh = (slosh * exp(-1.4f * dt)).coerceIn(0f, 1.2f)

        shownMl += (targetMl - shownMl) * (1 - exp(-5f * dt))
        if (abs(targetMl - shownMl) < 0.5f) shownMl = targetMl

        if (pour > 0) {
            pour = max(0f, pour - dt)
            bubbleClock += dt
            while (bubbleClock > 1f / 22) {
                bubbleClock -= 1f / 22
                spawnBubble(pourX + (random.nextFloat() - 0.5f) * 26f, 8f, 70f)
            }
            rippleClock += dt
            if (rippleClock > 0.18f) {
                rippleClock = 0f
                ripples += Ripple(pourX, 4f)
            }
        }

        if (level > 0.06f) {
            ambientClock += dt
            if (ambientClock > 1.1f) {
                ambientClock = 0f
                spawnBubble(random.nextFloat() * width, 30f, 220f)
            }
        }

        ripples.forEach { it.age += dt }
        ripples.removeAll { it.age > 3f }

        for (b in bubbles) {
            b.y -= b.speed * dt
            b.x += sin(time * 3 + b.phase) * 7f * dt
        }
        bubbles.removeAll { it.y - it.radius <= surfaceY(it.x) || it.y > height }
    }

    private fun spawnBubble(x: Float, minDepth: Float, maxDepth: Float) {
        val surface = surfaceY(x)
        val top = surface + minDepth
        val bottom = min(surface + maxDepth, height - 6f)
        if (bottom <= top) return
        bubbles += Bubble(
            x,
            top + random.nextFloat() * (bottom - top),
            1.2f + random.nextFloat() * 2.8f,
            20f + random.nextFloat() * 30f,
            random.nextFloat() * PI.toFloat() * 2,
        )
    }

    companion object {
        const val POUR_DURATION = 0.9f
    }
}
