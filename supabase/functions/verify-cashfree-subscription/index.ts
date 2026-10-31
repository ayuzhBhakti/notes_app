import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { createServiceClient, loadAppConfig } from "../_shared/app_config.ts";
import { cashfreeRequest } from "../_shared/cashfree.ts";
import {
  isProfileAccessActive,
  recordSubscriptionPayment,
  resolvePlanType,
} from "../_shared/subscription.ts";
import { logPayment, logPaymentError } from "../_shared/logger.ts";
import { paymentTypeFor, previousPaymentStatus, trackUserEvent } from "../_shared/mixpanel.ts";

const FN = "verify-cashfree-subscription";

interface VerifyRequest {
  subscription_id?: string;
}

interface CashfreeSubscription {
  subscription_id: string;
  subscription_status: string;
  plan_details?: {
    plan_id?: string;
  };
  authorisation_details?: {
    authorization_status?: string;
  };
}

interface CashfreeSubscriptionPayment {
  payment_id?: string;
  cf_payment_id?: string;
  payment_type?: string;
  payment_status?: string;
  payment_amount?: number | string;
  payment_time?: string;
  authorization_details?: {
    authorization_status?: string;
  };
}

interface ProfileRow {
  phone: string | null;
  subscription_status: string | null;
  subscription_ends_at: string | null;
  cashfree_subscription_id: string | null;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function createUserClient(authHeader: string) {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    { global: { headers: { Authorization: authHeader } } },
  );
}

function isAuthorizationSuccess(status: string | null | undefined): boolean {
  if (!status) return false;
  const normalized = status.toUpperCase();
  return normalized === "SUCCESS" || normalized === "ACTIVE";
}

function resolveAuthorizationStatus(
  subscription: CashfreeSubscription,
  payments: CashfreeSubscriptionPayment[],
): string | null {
  const authPayment = payments.find((payment) =>
    payment.payment_type?.toUpperCase() === "AUTH" &&
    payment.payment_status?.toUpperCase() === "SUCCESS"
  );
  if (authPayment?.authorization_details?.authorization_status) {
    return authPayment.authorization_details.authorization_status;
  }

  if (subscription.authorisation_details?.authorization_status) {
    return subscription.authorisation_details.authorization_status;
  }

  for (const payment of payments) {
    const status = payment.authorization_details?.authorization_status;
    if (status) return status;
  }

  return null;
}

function paymentIdFor(payment: CashfreeSubscriptionPayment, suffix: string): string {
  return payment.payment_id
    ?? payment.cf_payment_id
    ?? suffix;
}

Deno.serve(async (req) => {
  logPayment(FN, "request_received", { method: req.method });

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      logPayment(FN, "missing_auth_header", {}, "warn");
      return jsonResponse({ error: "Missing authorization header" }, 401);
    }

    const userClient = createUserClient(authHeader);
    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) {
      logPayment(FN, "unauthorized", { authError: userError?.message }, "warn");
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const body = await req.json().catch(() => ({})) as VerifyRequest;
    const serviceClient = createServiceClient();
    const config = await loadAppConfig(serviceClient);

    const { data: profile } = await serviceClient
      .from("profiles")
      .select("phone, subscription_status, subscription_ends_at, cashfree_subscription_id")
      .eq("id", user.id)
      .maybeSingle<ProfileRow>();

    const subscriptionId = body.subscription_id
      ?? profile?.cashfree_subscription_id;
    if (!subscriptionId) {
      logPayment(FN, "no_subscription_id", { userId: user.id }, "warn");
      return jsonResponse({ error: "No subscription to verify" }, 404);
    }

    logPayment(FN, "verifying", { userId: user.id, subscriptionId });

    const cashfree = await cashfreeRequest<CashfreeSubscription>(
      config,
      "GET",
      `/subscriptions/${encodeURIComponent(subscriptionId)}`,
    );

    const payments = await cashfreeRequest<CashfreeSubscriptionPayment[]>(
      config,
      "GET",
      `/subscriptions/${encodeURIComponent(subscriptionId)}/payments`,
    ).catch(() => [] as CashfreeSubscriptionPayment[]);

    const authorizationStatus = resolveAuthorizationStatus(cashfree, payments);
    const mandateSuccess = isAuthorizationSuccess(authorizationStatus);
    const phone = profile?.phone ?? null;

    logPayment(FN, "cashfree_status", {
      userId: user.id,
      subscriptionId,
      cashfreeStatus: cashfree.subscription_status,
      authorizationStatus,
      mandateSuccess,
      paymentCount: payments.length,
      payments: payments.map((p) => ({
        type: p.payment_type,
        status: p.payment_status,
        amount: p.payment_amount,
      })),
    });

    for (const payment of payments) {
      if (payment.payment_status?.toUpperCase() !== "SUCCESS") {
        continue;
      }

      const rawAmount = typeof payment.payment_amount === "number"
        ? payment.payment_amount
        : Number.parseFloat(String(payment.payment_amount ?? ""));
      const amount = Number.isFinite(rawAmount)
        ? rawAmount
        : config.cashfreeRecurringAmount;
      const planType = resolvePlanType(payment.payment_type, amount, config);
      const resolvedAmount = planType === "trial"
        ? config.cashfreeTrialAmount
        : config.cashfreeRecurringAmount;

      logPayment(FN, "recording_payment", {
        userId: user.id,
        subscriptionId,
        planType,
        amount: resolvedAmount,
        paymentType: payment.payment_type,
      });

      const paymentId = paymentIdFor(payment, `${subscriptionId}:${planType}`);
      const previousStatus = await previousPaymentStatus(
        serviceClient,
        cashfree.subscription_id,
        paymentId,
      );
      const { inserted } = await recordSubscriptionPayment(serviceClient, {
        userId: user.id,
        phone,
        paymentId,
        cashfreeSubscriptionId: cashfree.subscription_id,
        amount: resolvedAmount,
        planType,
        status: "success",
        paidAt: payment.payment_time ?? null,
      });
      // The webhook may have recorded (and sent) this payment already.
      if (inserted) {
        const paidAt = Date.parse(payment.payment_time ?? "");
        await trackUserEvent(serviceClient, config.mixpanelToken, {
          fn: FN,
          event: "Payment Succeeded",
          userId: user.id,
          insertId: paymentId,
          time: Number.isFinite(paidAt) ? Math.floor(paidAt / 1000) : undefined,
          properties: {
            payment_type: paymentTypeFor(planType, previousStatus),
            plan_type: planType,
            amount: resolvedAmount,
            currency: "INR",
            via: "verify",
          },
        });
      }
    }

    const { data: refreshedProfile } = await serviceClient
      .from("profiles")
      .select("subscription_status, subscription_ends_at")
      .eq("id", user.id)
      .maybeSingle<ProfileRow>();

    const accessActive = isProfileAccessActive(
      refreshedProfile?.subscription_status,
      refreshedProfile?.subscription_ends_at,
    ) || mandateSuccess;

    logPayment(FN, "verify_complete", {
      userId: user.id,
      subscriptionId,
      profileStatus: refreshedProfile?.subscription_status,
      accessActive,
      mandateSuccess,
    });

    return jsonResponse({
      subscription_id: cashfree.subscription_id,
      status: refreshedProfile?.subscription_status ?? (mandateSuccess ? "trial" : "pending"),
      cashfree_status: cashfree.subscription_status,
      authorization_status: authorizationStatus,
      mandate_success: mandateSuccess,
      is_active: accessActive,
    });
  } catch (error) {
    logPaymentError(FN, "failed", error);
    return jsonResponse({ error: (error as Error).message }, 500);
  }
});
