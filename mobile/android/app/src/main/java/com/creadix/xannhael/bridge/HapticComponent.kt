package com.creadix.xannhael.bridge

import android.content.Context
import android.os.VibrationEffect
import android.os.Vibrator
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeComponentFactory
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import org.json.JSONObject

/**
 * Native side of the "haptic" bridge component.
 *
 * Rails sends `{ component: "haptic", event: "vibrate", data: { feedback } }`
 * to give a short native vibration after an action.
 */
class HapticComponent(
    name: String,
    private val delegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, delegate) {

    override fun onReceive(message: Message) {
        when (message.event) {
            "vibrate" -> vibrate(message)
        }
    }

    private fun vibrate(message: Message) {
        val context = delegate.destination.fragment.requireContext()
        val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
        if (!vibrator.hasVibrator()) return

        val feedback = runCatching { JSONObject(message.jsonData).optString("feedback") }
            .getOrNull()
            .orEmpty()

        val effect = when (feedback) {
            "error" -> VibrationEffect.createPredefined(VibrationEffect.EFFECT_HEAVY_CLICK)
            "success" -> VibrationEffect.createPredefined(VibrationEffect.EFFECT_CLICK)
            else -> VibrationEffect.createPredefined(VibrationEffect.EFFECT_TICK)
        }
        vibrator.vibrate(effect)
    }

    companion object {
        const val NAME = "haptic"

        fun factory() = BridgeComponentFactory(NAME, ::HapticComponent)
    }
}