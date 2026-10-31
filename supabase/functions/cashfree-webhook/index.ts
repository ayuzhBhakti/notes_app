// Cashfree subscription webhook. Deployed with verify_jwt = false: Cashfree has no user token,
// so the request is trusted only after its signature is checked against the Cashfree secret.
//
// This is what keeps access going after the first day: the app is closed when the monthly debit
// happens, so nothing else would record it.

import { createServiceClient, loadAppConfig } from "../_shared/app_config.ts";
import { verifyCashfreeWebhookSignature } from "../_shared/cashfree.ts";
import {
  findProfileByCashfreeSubscription,
  findUserByLedgerSubscription,
  isCancellationStatus,
  isExpiredStatus,
  markSubscriptionCancelled,
  markSubscriptionExpired,
  recordSubscriptionPayment,
  resolvePaymentId,
  resolvePlanType,
} from "../_shared/subscription.ts";
import { logPayment, logPaymentError } from "../_shared/logger.ts";
import {
  paymentTypeFor,
  previousPaymentStatus,
  trackUserEvent,
} from "../_shared/mixpanel.ts";

const FN = "cashfree-webhook";

interface WebhookEnvelope {
  type?: string;
  data?: Record<string, unknown> & {
    subscription_id?: string;
    subscription_status?: string;
    payment_status?: string;
    payment_type?: string;
    payment_amount?: number | string;
    subscription_tags?: Record<string, string>;
  };
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function parseAmount(value: number | string | undefined, fallback: number): number {
  const parsed = typeof value === "number" ? value : Number.parseFloat(String(value ?? ""));
  return Number.isFinite(parsed) ? parsed : fallback;
}

function trackStatusChange(
  client: ReturnType<typeof createServiceClient>,
  token: string,
  userId: string,
  subscriptionId: string,
  change: { event: string; cashfreeStatus: string },
): Promise<void> {
  return trackUserEvent(client, token, {
    fn: FN,
    event: change.event,
    userId,
    insertId: `${subscriptionId}:${change.cashfreeStatus}`,
    properties: { cashfree_status: change.cashfreeStatus },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const rawBody = await req.text();
    const serviceClient = createServiceClient();
    const config = await loadAppConfig(serviceClient);

    const valid = await verifyCashfreeWebhookSignature(
      config,
      rawBody,
      req.headers.get("x-webhook-timestamp"),
      req.headers.get("x-webhook-signature"),
    );
    if (!valid) {
      logPayment(FN, "invalid_signature", {}, "warn");
      return jsonResponse({ error: "Invalid webhook signature" }, 401);
    }

    const payload = JSON.parse(rawBody) as WebhookEnvelope;
    const eventType = payload.type ?? "";
    const subscriptionId = payload.data?.subscription_id;
    if (!subscriptionId) {
      logPayment(FN, "ignored_no_subscription_id", { eventType }, "warn");
      return jsonResponse({ ok: true, ignored: true });
    }

    // One Cashfree account can serve several apps, and it sends every app's events to every
    // webhook URL. Only mandates this backend created (ids from create-cashfree-subscription
    // start with "ev_") are ours; another app's user id would not exist here.
    if (!subscriptionId.startsWith("ev_")) {
      logPayment(FN, "ignored_other_app", { eventType });
      return jsonResponse({ ok: true, ignored: true, reason: "other_app" });
    }

    let userId: string | null = payload.data?.subscription_tags?.user_id ?? null;
    if (!userId) {
      userId = (await findProfileByCashfreeSubscription(serviceClient, subscriptionId))?.id ?? null;
    }
    if (!userId) {
      userId = await findUserByLedgerSubscription(serviceClient, subscriptionId);
    }
    if (!userId) {
      logPayment(FN, "ignored_user_not_found", { subscriptionId, eventType }, "warn");
      return jsonResponse({ ok: true, ignored: true, reason: "user_not_found" });
    }

    const { data: profile } = await serviceClient
      .from("profiles")
      .select("phone, cashfree_subscription_id, subscription_status")
      .eq("id", userId)
      .maybeSingle();
    const phone: string | null = profile?.phone ?? null;
    // False when the profile now points at a newer mandate than the one this event is about.
    const mandateOnProfile = !profile?.cashfree_subscription_id ||
      profile.cashfree_subscription_id === subscriptionId;

    logPayment(FN, "event", { eventType, subscriptionId, userId, mandateOnProfile });

    const amount = parseAmount(payload.data?.payment_amount, config.cashfreeRecurringAmount);
    const planType = resolvePlanType(payload.data?.payment_type, amount, config);
    const paymentId = resolvePaymentId(payload.data ?? {}, subscriptionId, eventType);

    // Read before the payment is recorded, so it is the one before this.
    const previousStatus = eventType.startsWith("SUBSCRIPTION_PAYMENT_")
      ? await previousPaymentStatus(serviceClient, subscriptionId, paymentId)
      : null;

    if (
      eventType === "SUBSCRIPTION_PAYMENT_SUCCESS" &&
      payload.data?.payment_status?.toUpperCase() === "SUCCESS"
    ) {
      const recordedAmount = planType === "trial"
        ? config.cashfreeTrialAmount
        : config.cashfreeRecurringAmount;
      const { inserted } = await recordSubscriptionPayment(serviceClient, {
        userId,
        phone,
        paymentId,
        cashfreeSubscriptionId: subscriptionId,
        amount: recordedAmount,
        planType,
        status: "success",
      });
      logPayment(FN, "payment_success_recorded", { userId, subscriptionId, planType, inserted });
      // Only a payment recorded now: a repeated webhook must not count twice.
      if (inserted) {
        await trackUserEvent(serviceClient, config.mixpanelToken, {
          fn: FN,
          event: "Payment Succeeded",
          userId,
          insertId: paymentId,
          properties: {
            payment_type: paymentTypeFor(planType, previousStatus),
            plan_type: planType,
            amount: recordedAmount,
            currency: "INR",
            via: "webhook",
          },
        });
      }
    }

    if (eventType === "SUBSCRIPTION_PAYMENT_FAILED") {
      const { inserted } = await recordSubscriptionPayment(serviceClient, {
        userId,
        phone,
        paymentId,
        cashfreeSubscriptionId: subscriptionId,
        amount: config.cashfreeRecurringAmount,
        planType,
        status: "failed",
        expireProfileOnFailure: mandateOnProfile,
      });
      logPayment(FN, "payment_failed_recorded", { userId, subscriptionId, planType, inserted }, "warn");
      if (inserted) {
        await trackUserEvent(serviceClient, config.mixpanelToken, {
          fn: FN,
          event: "Payment Failed",
          userId,
          insertId: paymentId,
          properties: {
            payment_type: paymentTypeFor(planType, previousStatus),
            plan_type: planType,
            amount: planType === "trial"
              ? config.cashfreeTrialAmount
              : config.cashfreeRecurringAmount,
            currency: "INR",
            via: "webhook",
          },
        });
      }
    }

    if (eventType === "SUBSCRIPTION_STATUS_CHANGED") {
      const cashfreeStatus = payload.data?.subscription_status?.toUpperCase() ?? "";
      const statusAlreadyEnded = profile?.subscription_status === "cancelled" ||
        profile?.subscription_status === "expired";
      // A change on an older mandate says nothing about the one the user is on now.
      if (!mandateOnProfile) {
        logPayment(FN, "status_change_for_old_mandate", { userId, subscriptionId, cashfreeStatus });
      } else if (isCancellationStatus(cashfreeStatus)) {
        await markSubscriptionCancelled(serviceClient, userId);
        // Sent only on the change itself: Cashfree may repeat the webhook.
        if (!statusAlreadyEnded) {
          await trackStatusChange(serviceClient, config.mixpanelToken, userId, subscriptionId, {
            event: "Subscription Cancelled",
            cashfreeStatus,
          });
        }
      } else if (isExpiredStatus(cashfreeStatus)) {
        await markSubscriptionExpired(serviceClient, userId);
        if (profile?.subscription_status !== "expired") {
          await trackStatusChange(serviceClient, config.mixpanelToken, userId, subscriptionId, {
            event: "Subscription Expired",
            cashfreeStatus,
          });
        }
      }
    }

    return jsonResponse({ ok: true });
  } catch (error) {
    logPaymentError(FN, "failed", error);
    return jsonResponse({ error: (error as Error).message }, 500);
  }
});
