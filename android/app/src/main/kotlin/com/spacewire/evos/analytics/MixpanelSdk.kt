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

    // Written by versions before 2026-10-31: the old install_* properties. Replaced by the
    // first setAttribution call.
    private const val KEY_LEGACY_PROPERTIES = "properties"
    private const val KEY_LATEST = "attribution_latest"
    private const val KEY_FIRST = "attribution_first"

    /** Every attribution super property, old and new, so a changed ad leaves no stale field. */
    private val ATTRIBUTION_KEYS = listOf(
        "install_source", "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "campaign_id", "adset_id", "ad_id",
        "install_medium", "install_organic", "install_campaign", "install_content", "install_term",
    )

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
        applyAttribution(app)
    }

    fun isConfigured(context: Context): Boolean {
        val token = token(context)
        return token.isNotBlank() && token != TOKEN_PLACEHOLDER
    }

    fun instance(): MixpanelAPI? = mixpanel

    /**
     * Kept by the app as well as by Mixpanel, because the app learns where the install came from
     * only once and Mixpanel forgets its properties on reset. [latest] is the latest ad (last
     * touch); [first] is the first touch, as first_* plus install_source.
     */
    fun saveAttribution(context: Context, latest: Map<String, Any?>, first: Map<String, Any?>) {
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_LATEST, JSONObject(latest).toString())
            .putString(KEY_FIRST, JSONObject(first).toString())
            .remove(KEY_LEGACY_PROPERTIES)
            .apply()
        applyAttribution(context)
    }

    /**
     * Puts the stored ad back on every event and on the person. Needed at start, after a sign-in
     * (the profile becomes known) and after a sign-out (the reset wiped it).
     */
    fun applyAttribution(context: Context) {
        val instance = mixpanel ?: return
        val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val latest = prefs.getString(KEY_LATEST, null)?.let(::JSONObject)
        if (latest == null) {
            // Not attributed by this version yet: keep what an older one stored.
            val legacy = prefs.getString(KEY_LEGACY_PROPERTIES, null) ?: return
            instance.registerSuperProperties(JSONObject(legacy))
            instance.people.setOnce(JSONObject(legacy))
            return
        }
        ATTRIBUTION_KEYS.forEach(instance::unregisterSuperProperty)
        instance.registerSuperProperties(latest)
        // The person shows the latest ad; install_source on the person is the first one's. A field
        // the new ad lacks is cleared, as on the profiles row, so no old ad's field lingers.
        ATTRIBUTION_KEYS
            .filter { it != "install_source" && !latest.has(it) }
            .forEach(instance.people::unset)
        instance.people.set(JSONObject(latest.toString()).apply { remove("install_source") })
        prefs.getString(KEY_FIRST, null)?.let {
            // setOnce: a reinstall or a newer ad never overwrites the first touch.
            instance.people.setOnce(JSONObject(it))
        }
    }

    private fun token(context: Context): String = context.getString(R.string.mixpanel_token)

    internal fun isDebuggable(context: Context): Boolean =
        context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
}
