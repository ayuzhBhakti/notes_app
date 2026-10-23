package com.spacewire.evos.analytics

import android.content.Context
import android.content.pm.ApplicationInfo
import android.util.Log
import com.mixpanel.android.mpmetrics.MixpanelAPI
import com.spacewire.evos.R
import org.json.JSONObject

object MixpanelSdk {

    private const val TAG = "MixpanelSdk"
    private const val TOKEN_PLACEHOLDER = "YOUR_MIXPANEL_TOKEN"
    private const val PREFS = "analytics_install_source"
    private const val KEY_PROPERTIES = "properties"

    private var mixpanel: MixpanelAPI? = null

    fun initialize(context: Context) {
        val app = context.applicationContext
        if (!isConfigured(app)) {
            if (isDebuggable(app)) {
                Log.w(TAG, "Mixpanel disabled: set mixpanel_token in res/values/analytics_keys.xml")
            }
            return
        }
        // false: Mixpanel's own automatic events (first open, app updated, session) stay off.
        val instance = MixpanelAPI.getInstance(app, token(app), false)
        if (isDebuggable(app)) {
            instance.setEnableLogging(true)
        }
        instance.registerSuperProperties(
            JSONObject().apply {
                put("platform", "android")
                put("app_version", app.packageManager.getPackageInfo(app.packageName, 0).versionName)
            },
        )
        mixpanel = instance
        applyInstallSource(app)
    }

    fun isConfigured(context: Context): Boolean {
        val token = token(context)
        return token.isNotBlank() && token != TOKEN_PLACEHOLDER
    }

    fun instance(): MixpanelAPI? = mixpanel

    /**
     * Kept by the app as well as by Mixpanel, because the app learns the install source only once
     * (on first launch) and Mixpanel forgets its properties on reset.
     */
    fun saveInstallSource(context: Context, properties: Map<String, Any?>) {
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PROPERTIES, JSONObject(properties).toString())
            .apply()
        applyInstallSource(context)
    }

    /**
     * Puts the stored install source back on every event and on the person. Needed after a
     * sign-in (the profile becomes known) and after a sign-out (the reset wiped it).
     */
    fun applyInstallSource(context: Context) {
        val instance = mixpanel ?: return
        val stored = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_PROPERTIES, null) ?: return
        instance.registerSuperProperties(JSONObject(stored))
        // setOnce: the first source a person ever came from is never overwritten by a reinstall.
        instance.people.setOnce(JSONObject(stored))
    }

    private fun token(context: Context): String = context.getString(R.string.mixpanel_token)

    internal fun isDebuggable(context: Context): Boolean =
        context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
}
