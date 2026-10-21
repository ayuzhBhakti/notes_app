package com.spacewire.evos.analytics

import android.app.Application
import android.content.Context
import android.util.Log
import com.facebook.FacebookSdk
import com.facebook.LoggingBehavior
import com.facebook.appevents.AppEventsLogger
import com.spacewire.evos.R

object MetaSdk {

    private const val TAG = "MetaSdk"
    private const val APP_ID_PLACEHOLDER = "YOUR_FACEBOOK_APP_ID"
    private const val CLIENT_TOKEN_PLACEHOLDER = "YOUR_FACEBOOK_CLIENT_TOKEN"

    /** True once the SDK has been started with real keys. Events are dropped until then. */
    var isReady: Boolean = false
        private set

    fun initialize(application: Application) {
        if (!isConfigured(application)) {
            if (MixpanelSdk.isDebuggable(application)) {
                Log.w(TAG, "Facebook SDK disabled: set facebook_app_id and facebook_client_token in res/values/analytics_keys.xml")
            }
            return
        }
        // AndroidManifest.xml switches off the SDK's start-up initialisation and automatic events,
        // so that a build still carrying the placeholder keys never contacts Facebook. With real
        // keys, both are switched back on here.
        if (MixpanelSdk.isDebuggable(application)) {
            // Shows each request to Facebook and each App Events flush in logcat, as Mixpanel's
            // logging does, so a debug build can be checked without Events Manager.
            FacebookSdk.setIsDebugEnabled(true)
            FacebookSdk.addLoggingBehavior(LoggingBehavior.APP_EVENTS)
            FacebookSdk.addLoggingBehavior(LoggingBehavior.REQUESTS)
        }
        FacebookSdk.setAutoInitEnabled(true)
        FacebookSdk.setAutoLogAppEventsEnabled(true)
        FacebookSdk.fullyInitialize()
        // Reports installs and app opens.
        AppEventsLogger.activateApp(application)
        isReady = true
    }

    fun isConfigured(context: Context): Boolean {
        val appId = context.getString(R.string.facebook_app_id)
        val clientToken = context.getString(R.string.facebook_client_token)
        return appId.isNotBlank() &&
            clientToken.isNotBlank() &&
            appId != APP_ID_PLACEHOLDER &&
            clientToken != CLIENT_TOKEN_PLACEHOLDER
    }
}
