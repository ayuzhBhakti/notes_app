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
      .select("phone, cashfree_subscription_id")
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

    if (
      eventType === "SUBSCRIPTION_PAYMENT_SUCCESS" &&
      payload.data?.payment_status?.toUpperCase() === "SUCCESS"
    ) {
      const { inserted } = await recordSubscriptionPayment(serviceClient, {
        userId,
        phone,
        paymentId,
        cashfreeSubscriptionId: subscriptionId,
        amount: planType === "trial" ? config.cashfreeTrialAmount : config.cashfreeRecurringAmount,
        planType,
        status: "success",
      });
      logPayment(FN, "payment_success_recorded", { userId, subscriptionId, planType, inserted });
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
    }

    if (eventType === "SUBSCRIPTION_STATUS_CHANGED") {
      const cashfreeStatus = payload.data?.subscription_status?.toUpperCase() ?? "";
      // A change on an older mandate says nothing about the one the user is on now.
      if (!mandateOnProfile) {
        logPayment(FN, "status_change_for_old_mandate", { userId, subscriptionId, cashfreeStatus });
      } else if (isCancellationStatus(cashfreeStatus)) {
        await markSubscriptionCancelled(serviceClient, userId);
      } else if (isExpiredStatus(cashfreeStatus)) {
        await markSubscriptionExpired(serviceClient, userId);
      }
    }

    return jsonResponse({ ok: true });
  } catch (error) {
    logPaymentError(FN, "failed", error);
    return jsonResponse({ error: (error as Error).message }, 500);
  }
});
