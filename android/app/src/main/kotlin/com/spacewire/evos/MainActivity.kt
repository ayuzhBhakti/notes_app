package com.spacewire.evos

import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import com.spacewire.evos.analytics.AnalyticsChannel
import com.spacewire.evos.payments.PaymentsChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Starts Mixpanel and the Facebook SDK, and answers
        // lib/services/analytics.dart.
        AnalyticsChannel.register(application, flutterEngine.dartExecutor.binaryMessenger)

        // Cashfree UPI AutoPay, for lib/services/payment_gateway.dart.
        PaymentsChannel.register(this, flutterEngine.dartExecutor.binaryMessenger)

        // Read by lib/services/install_referrer_service.dart.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.spacewire.evos/install_referrer",
        ).setMethodCallHandler { call, result ->
            if (call.method == "getInstallReferrer") {
                fetchInstallReferrer(result)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun fetchInstallReferrer(result: MethodChannel.Result) {
        val client = InstallReferrerClient.newBuilder(applicationContext).build()
        // Both callbacks can fire for one connection, and replying twice on a
        // MethodChannel.Result throws.
        var replied = false

        try {
            client.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(responseCode: Int) {
                    if (replied) return
                    replied = true
                    if (responseCode == InstallReferrerClient.InstallReferrerResponse.OK) {
                        try {
                            val details = client.installReferrer
                            // The timestamps tell "Play saw no link click" (0)
                            // apart from "Play saw one but sent no referrer".
                            result.success(
                                mapOf(
                                    "referrer" to (details.installReferrer ?: ""),
                                    "clickSeconds" to details.referrerClickTimestampSeconds,
                                    "installBeginSeconds" to details.installBeginTimestampSeconds,
                                ),
                            )
                        } catch (e: Exception) {
                            result.error("unavailable", e.message, null)
                        }
                    } else {
                        result.error("unavailable", "Response code $responseCode", null)
                    }
                    client.endConnection()
                }

                override fun onInstallReferrerServiceDisconnected() {
                    if (replied) return
                    replied = true
                    result.error("unavailable", "Play Store disconnected", null)
                }
            })
        } catch (e: Exception) {
            // Thrown when the device has no Play Store to bind to.
            if (!replied) {
                replied = true
                result.error("unavailable", e.message, null)
            }
        }
    }
}
