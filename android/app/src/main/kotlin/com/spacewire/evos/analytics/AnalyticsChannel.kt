package com.spacewire.evos.analytics

import android.app.Application
import android.os.Bundle
import android.util.Log
import com.facebook.appevents.AppEventsConstants
import com.facebook.appevents.AppEventsLogger
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.math.BigDecimal
import java.util.Currency

/**
 * Receives every analytics call from lib/services/analytics.dart and hands it to Mixpanel or the
 * Facebook SDK. Each call is answered true when it reached an SDK and false when that SDK has no
 * key; it never answers with an error, because analytics must not be able to break the app.
 */
class AnalyticsChannel private constructor(private val application: Application) :
    MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "AnalyticsChannel"

        // Must equal the channel name in lib/services/analytics.dart.
        private const val NAME = "com.spacewire.evos/analytics"

        fun register(application: Application, messenger: BinaryMessenger) {
            runCatching { MixpanelSdk.initialize(application) }
                .onFailure { Log.w(TAG, "Mixpanel could not start", it) }
            runCatching { MetaSdk.initialize(application) }
                .onFailure { Log.w(TAG, "Facebook SDK could not start", it) }
            MethodChannel(messenger, NAME).setMethodCallHandler(AnalyticsChannel(application))
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val sent = runCatching { handle(call) }
            .onFailure { Log.w(TAG, "${call.method} failed", it) }
            .getOrDefault(false)
        if (sent == null) result.notImplemented() else result.success(sent)
    }

    /** Null for a method this class does not know. */
    private fun handle(call: MethodCall): Boolean? = when (call.method) {
        "track" -> mixpanel { track(call.argument<String>("event")!!, json(call.argument("properties"))) }
        "identify" -> mixpanel {
            // Also links the events this device sent before sign-in to the person.
            identify(call.argument<String>("id")!!)
            call.argument<String>("name")?.takeIf { it.isNotBlank() }?.let { people.set("\$name", it) }
            call.argument<String>("email")?.takeIf { it.isNotBlank() }?.let { people.set("\$email", it) }
            MixpanelSdk.applyInstallSource(application)
        }
        "reset" -> mixpanel {
            reset()
            // The reset wipes Mixpanel's stored properties; where the install came from still holds.
            MixpanelSdk.applyInstallSource(application)
        }
        "setInstallSource" -> {
            // Stored even without a Mixpanel key: Play is asked only once, on first launch.
            MixpanelSdk.saveInstallSource(application, call.argument<Map<String, Any?>>("properties")!!)
            MixpanelSdk.instance() != null
        }
        "metaCompleteRegistration" -> meta {
            logEvent(
                AppEventsConstants.EVENT_NAME_COMPLETED_REGISTRATION,
                Bundle().apply {
                    putString(AppEventsConstants.EVENT_PARAM_REGISTRATION_METHOD, call.argument<String>("method"))
                },
            )
        }
        "metaInitiateCheckout" -> meta {
            logEvent(
                AppEventsConstants.EVENT_NAME_INITIATED_CHECKOUT,
                call.argument<Number>("amount")!!.toDouble(),
                planParams(call),
            )
        }
        "metaSubscribe" -> meta {
            val params = planParams(call)
            logPurchase(
                BigDecimal.valueOf(call.argument<Number>("amount")!!.toDouble()),
                Currency.getInstance(call.argument<String>("currency")!!),
                params,
            )
            logEvent(AppEventsConstants.EVENT_NAME_SUBSCRIBE, params)
        }
        else -> null
    }

    private fun mixpanel(action: com.mixpanel.android.mpmetrics.MixpanelAPI.() -> Unit): Boolean {
        val instance = MixpanelSdk.instance() ?: return false
        instance.action()
        return true
    }

    private fun meta(action: AppEventsLogger.() -> Unit): Boolean {
        if (!MetaSdk.isReady) return false
        AppEventsLogger.newLogger(application).action()
        return true
    }

    private fun planParams(call: MethodCall): Bundle = Bundle().apply {
        putString(AppEventsConstants.EVENT_PARAM_CONTENT_ID, call.argument<String>("plan_id"))
        putString(AppEventsConstants.EVENT_PARAM_CURRENCY, call.argument<String>("currency"))
    }

    private fun json(properties: Map<String, Any?>?): JSONObject? =
        properties?.takeIf { it.isNotEmpty() }?.let { JSONObject(it) }
}
