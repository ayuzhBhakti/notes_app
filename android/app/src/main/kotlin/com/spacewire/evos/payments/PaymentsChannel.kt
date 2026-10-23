package com.spacewire.evos.payments

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import com.cashfree.pg.api.CFPaymentGatewayService
import com.cashfree.pg.core.api.CFSubscriptionSession
import com.cashfree.pg.core.api.callback.CFSubscriptionResponseCallback
import com.cashfree.pg.core.api.subscription.upi.CFSubsUpi
import com.cashfree.pg.core.api.subscription.upi.CFSubsUpiPayment
import com.cashfree.pg.core.api.utils.CFErrorResponse
import com.cashfree.pg.core.api.utils.CFSubscriptionResponse
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Cashfree UPI AutoPay for lib/services/payment_gateway.dart: lists the UPI
 * apps on the phone and opens one to approve a subscription mandate (UPI
 * Intent mode, no hosted web page).
 *
 * `startSubscription` answers as soon as the UPI app is opened. Cashfree's
 * callback is sent to Dart separately (`cashfreeResult`), and Dart decides how
 * long to wait for it: Cashfree does not always call back when the user
 * returns without paying, and holding the call open until it did left the
 * paywall loading for a long time. The same flow as CashAlert's PaywallActivity.
 *
 * The channel name must match the one in payment_gateway.dart.
 */
class PaymentsChannel private constructor(
    private val activity: Activity,
    private val channel: MethodChannel,
) : MethodChannel.MethodCallHandler, CFSubscriptionResponseCallback {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "upiApps" -> result.success(installedUpiApps())
            "startSubscription" -> startSubscription(call, result)
            else -> result.notImplemented()
        }
    }

    private fun installedUpiApps(): List<Map<String, String>> =
        UPI_APPS.filter { canTakeUpiIntent(it.first) }
            .map { mapOf("package" to it.first, "name" to it.second) }

    private fun canTakeUpiIntent(packageName: String): Boolean {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(UPI_PROBE_URI)).setPackage(packageName)
        return activity.packageManager
            .queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
            .isNotEmpty()
    }

    private fun startSubscription(call: MethodCall, result: MethodChannel.Result) {
        val subscriptionId = call.argument<String>("subscriptionId")
        val sessionId = call.argument<String>("sessionId")
        val upiPackage = call.argument<String>("upiPackage")
        if (subscriptionId == null || sessionId == null || upiPackage == null) {
            result.error("failed", null, "bad_arguments")
            return
        }
        if (!canTakeUpiIntent(upiPackage)) {
            result.error("upi_app_unavailable", null, null)
            return
        }

        // Only the exact word is production, so nothing else can reach real money.
        val environment =
            if (call.argument<String>("environment").equals("production", ignoreCase = true)) {
                CFSubscriptionSession.Environment.PRODUCTION
            } else {
                CFSubscriptionSession.Environment.SANDBOX
            }

        try {
            val session = CFSubscriptionSession.CFSubscriptionSessionBuilder()
                .setEnvironment(environment)
                .setSubscriptionSessionID(sessionId)
                .setSubscriptionId(subscriptionId)
                .build()
            val upi = CFSubsUpi.CFSubsUpiBuilder()
                .setMode(CFSubsUpi.Mode.INTENT)
                .setUPIID(upiPackage)
                .build()
            val payment = CFSubsUpiPayment.CFSubsUpiPaymentBuilder()
                .setSubscriptionSession(session)
                .setSubsUpi(upi)
                .build()

            val service = CFPaymentGatewayService.getInstance()
            service.setSubscriptionCheckoutCallback(this)
            service.doSubscriptionPayment(activity, payment)
            // Answer now: the outcome arrives separately on `cashfreeResult`.
            result.success(null)
        } catch (e: Exception) {
            result.error("failed", null, "launch_failed")
        }
    }

    // The UPI app has reported back. Whether the mandate really went through
    // is decided by the server, which Dart asks next.
    override fun onSubscriptionVerify(response: CFSubscriptionResponse) {
        send(response.subscriptionId, ok = true, code = null)
    }

    // Cashfree's code only. Its message is free text and is not passed on.
    override fun onSubscriptionFailure(error: CFErrorResponse) {
        send(null, ok = false, code = error.code)
    }

    private fun send(subscriptionId: String?, ok: Boolean, code: String?) {
        activity.runOnUiThread {
            channel.invokeMethod(
                "cashfreeResult",
                mapOf("subscriptionId" to subscriptionId, "ok" to ok, "code" to code),
            )
        }
    }

    companion object {
        private const val CHANNEL = "com.spacewire.evos/payments"
        private const val UPI_PROBE_URI = "upi://pay?pa=test@upi&pn=Test&am=1.00&cu=INR"

        // In the order offered. Each also needs a <package> entry under
        // <queries> in AndroidManifest.xml, or Android 11+ reports it missing.
        private val UPI_APPS = listOf(
            "com.phonepe.app" to "PhonePe",
            "com.google.android.apps.nbu.paisa.user" to "Google Pay",
            "net.one97.paytm" to "Paytm",
            "in.org.npci.upiapp" to "BHIM",
        )

        fun register(activity: Activity, messenger: BinaryMessenger) {
            val channel = MethodChannel(messenger, CHANNEL)
            val handler = PaymentsChannel(activity, channel)
            channel.setMethodCallHandler(handler)
            // Registered now, not only when a payment starts: if Android
            // recreated the activity while the UPI app was in front, the answer
            // must still reach this one (CashAlert does the same in onCreate).
            runCatching {
                CFPaymentGatewayService.getInstance().setSubscriptionCheckoutCallback(handler)
            }
        }
    }
}
