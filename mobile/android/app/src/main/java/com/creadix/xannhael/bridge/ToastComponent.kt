package com.creadix.xannhael.bridge

import android.widget.Toast
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeComponentFactory
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import org.json.JSONObject

/**
 * Native side of the "toast" bridge component.
 *
 * Rails sends `{ component: "toast", event: "show", data: { message } }`
 * (bridge/toast_controller.js) to show a brief native Toast after an action.
 * No-op in the browser, where the web toast_controller renders an HTML toast.
 */
class ToastComponent(
    name: String,
    private val delegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, delegate) {

    override fun onReceive(message: Message) {
        when (message.event) {
            "show" -> showToast(message)
        }
    }

    private fun showToast(message: Message) {
        val text = runCatching { JSONObject(message.jsonData).optString("message") }
            .getOrNull()
            ?.takeIf { it.isNotBlank() }
            ?: return

        Toast.makeText(
            delegate.destination.fragment.requireContext(),
            text,
            Toast.LENGTH_SHORT
        ).show()
    }

    companion object {
        const val NAME = "toast"

        fun factory() = BridgeComponentFactory(NAME, ::ToastComponent)
    }
}