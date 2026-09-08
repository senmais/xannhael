package com.creadix.xannhael

import android.os.Bundle
import android.view.View
import androidx.activity.enableEdgeToEdge
import dev.hotwire.navigation.activities.HotwireActivity
import dev.hotwire.navigation.navigator.NavigatorConfiguration
import dev.hotwire.navigation.tabs.HotwireBottomNavigationController
import dev.hotwire.navigation.tabs.HotwireBottomTab
import dev.hotwire.navigation.tabs.navigatorConfigurations

class MainActivity : HotwireActivity() {
    private val tabBarController by lazy {
        HotwireBottomNavigationController(
            activity = this,
            view = findViewById(R.id.tab_bar),
            lazyLoadTabs = true
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        tabBarController.load(tabs)

        // Fade the tab content in on switch so the native shell feels animated
        // and coherent with the web View Transitions.
        tabBarController.setOnTabSelectedListener { _, tab ->
            findViewById<View>(tab.configuration.navigatorHostId).apply {
                alpha = 0f
                animate().alpha(1f).setDuration(220).start()
            }
        }
    }

    override fun navigatorConfigurations() = tabs.navigatorConfigurations

    private companion object {
        val tabs = listOf(
            tab("Ruby", R.drawable.ic_ruby, "ruby", R.id.ruby_navigator_host),
            tab("Hotwire", R.drawable.ic_hotwire, "hotwire", R.id.hotwire_navigator_host),
            tab("Kamal", R.drawable.ic_kamal, "kamal", R.id.kamal_navigator_host),
            tab("Omarchy", R.drawable.ic_omarchy, "omarchy", R.id.omarchy_navigator_host)
        )

        private fun tab(title: String, iconResId: Int, option: String, navigatorHostId: Int) =
            HotwireBottomTab(
                title = title,
                iconResId = iconResId,
                configuration = NavigatorConfiguration(
                    name = option,
                    navigatorHostId = navigatorHostId,
                    startLocation = "${BuildConfig.BASE_URL}/?option=$option"
                )
            )
    }
}