package com.creadix.xannhael

import android.app.Application
import com.creadix.xannhael.bridge.ButtonComponent
import com.creadix.xannhael.bridge.HapticComponent
import com.creadix.xannhael.bridge.NavbarComponent
import com.creadix.xannhael.bridge.ToastComponent
import dev.hotwire.core.bridge.KotlinXJsonConverter
import dev.hotwire.core.config.Hotwire
import dev.hotwire.core.logging.HotwireLogLevel
import dev.hotwire.core.turbo.config.PathConfiguration
import dev.hotwire.navigation.config.registerBridgeComponents

class XannhaelApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        configureHotwire()
    }

    private fun configureHotwire() {
        Hotwire.config.jsonConverter = KotlinXJsonConverter()
        Hotwire.config.webViewDebuggingEnabled = BuildConfig.DEBUG
        Hotwire.config.logger.logLevel =
            if (BuildConfig.DEBUG) HotwireLogLevel.DEBUG else HotwireLogLevel.NONE

        Hotwire.registerBridgeComponents(
            ButtonComponent.factory(),
            NavbarComponent.factory(),
            ToastComponent.factory(),
            HapticComponent.factory()
        )

        Hotwire.loadPathConfiguration(
            context = this,
            location = PathConfiguration.Location(
                assetFilePath = "json/configuration.json"
            )
        )
    }
}