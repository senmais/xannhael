package com.creadix.xannhael.bridge

import androidx.appcompat.widget.Toolbar
import androidx.core.view.isVisible
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeComponentFactory
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import dev.hotwire.navigation.fragments.HotwireFragment
import org.json.JSONObject

/**
 * Native side of the "navbar" bridge component.
 *
 * Rails sends `{ component: "navbar", event: "connect", data: { title } }`
 * (bridge/navbar_controller.js) so the native toolbar mirrors the current page.
 * `hide`/`show` let the web control the toolbar visibility for a given page.
 * No-op in the browser, where the navbar is the regular Turbo Drive nav bar.
 */
class NavbarComponent(
    name: String,
    private val delegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, delegate) {

    override fun onReceive(message: Message) {
        when (message.event) {
            "connect" -> connect(message)
            "hide" -> setToolbarVisible(false)
            "show" -> setToolbarVisible(true)
        }
    }

    private fun connect(message: Message) {
        val toolbar = toolbar() ?: return
        val title = runCatching { JSONObject(message.jsonData).optString("title") }
            .getOrNull()
            ?.takeIf { it.isNotBlank() }
        if (title != null) toolbar.title = title
        toolbar.isVisible = true
    }

    private fun setToolbarVisible(visible: Boolean) {
        toolbar()?.isVisible = visible
    }

    private fun toolbar(): Toolbar? =
        (delegate.destination.fragment as? HotwireFragment)?.toolbarForNavigation()

    companion object {
        const val NAME = "navbar"

        fun factory() = BridgeComponentFactory(NAME, ::NavbarComponent)
    }
}