package com.creadix.xannhael.bridge

import android.graphics.Color
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup
import android.widget.TextView
import androidx.appcompat.widget.Toolbar
import com.google.android.material.color.MaterialColors
import dev.hotwire.core.bridge.BridgeComponent
import dev.hotwire.core.bridge.BridgeComponentFactory
import dev.hotwire.core.bridge.BridgeDelegate
import dev.hotwire.core.bridge.Message
import dev.hotwire.navigation.destinations.HotwireDestination
import dev.hotwire.navigation.fragments.HotwireFragment
import org.json.JSONObject

/**
 * Minimal native side of the "button" bridge component.
 *
 * Rails elements with `data-controller="bridge--button"` present an action as a
 * native toolbar button. Tapping the toolbar button replies to the web with the
 * received "connect" message, which makes the Stimulus controller click the
 * underlying HTML element (a Rails form/link with an HTML fallback).
 */
class ButtonComponent(
    name: String,
    private val delegate: BridgeDelegate<HotwireDestination>
) : BridgeComponent<HotwireDestination>(name, delegate) {

    private val toolbarButtons = mutableListOf<TextView>()

    override fun onReceive(message: Message) {
        when (message.event) {
            "right" -> addButton(message)
            "disconnect" -> removeButtons()
        }
    }

    private fun addButton(message: Message) {
        val fragment = delegate.destination.fragment as? HotwireFragment ?: return
        val toolbar = fragment.toolbarForNavigation() ?: return
        val title = runCatching { JSONObject(message.jsonData).optString("title") }
            .getOrNull()
            ?.takeIf { it.isNotBlank() }
            ?: return

        val button = TextView(fragment.requireContext()).apply {
            this.text = title
            setTextColor(MaterialColors.getColor(
                this,
                com.google.android.material.R.attr.colorOnSurface,
                Color.WHITE
            ))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            setPadding(dp(10, fragment), 0, dp(10, fragment), 0)
            setOnClickListener { replyWith(message) }
        }

        toolbar.addView(
            button,
            Toolbar.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
                Gravity.END
            )
        )
        toolbarButtons.add(button)
    }

    private fun removeButtons() {
        val fragment = delegate.destination.fragment as? HotwireFragment
        val toolbar = fragment?.toolbarForNavigation()
        toolbarButtons.forEach { toolbar?.removeView(it) }
        toolbarButtons.clear()
    }

    private fun dp(value: Int, fragment: HotwireFragment): Int =
        (value * fragment.resources.displayMetrics.density).toInt()

    companion object {
        const val NAME = "button"

        fun factory() = BridgeComponentFactory(NAME, ::ButtonComponent)
    }
}