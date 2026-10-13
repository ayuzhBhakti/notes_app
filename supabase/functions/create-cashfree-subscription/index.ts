import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { createServiceClient, loadAppConfig } from "../_shared/app_config.ts";
import {
  buildPlanDetails,
  cashfreeRequest,
  fallbackCustomerEmail,
  normalizeIndianPhone,
} from "../_shared/cashfree.ts";
import {
  isProfileAccessActive,
  markProfilePendingMandate,
} from "../_shared/subscription.ts";
import { logPayment, logPaymentError } from "../_shared/logger.ts";

const FN = "create-cashfree-subscription";

interface CreateSubscriptionResponse {
  subscription_id: string;
  subscription_session_id: string;
  subscription_status?: string;
}

interface ProfileRow {
  phone: string | null;
  subscription_status: string | null;
  subscription_ends_at: string | null;
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

function firstRecurringChargeTime(): string {
  return new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
}

Deno.serve(async (req) => {
  logPayment(FN, "request_received", { method: req.method });

  if (req.method !== "POST") {
    logPayment(FN, "method_not_allowed", { method: req.method }, "warn");
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

    logPayment(FN, "user_authenticated", { userId: user.id });

    const serviceClient = createServiceClient();
    const config = await loadAppConfig(serviceClient);

    logPayment(FN, "config_loaded", {
      environment: config.cashfreeEnvironment,
      trialAmount: config.cashfreeTrialAmount,
      recurringAmount: config.cashfreeRecurringAmount,
      planId: config.cashfreePlanId || "(inline)",
      hasAppId: !!config.cashfreeAppId,
    });

    const { data: profile } = await serviceClient
      .from("profiles")
      .select("phone, subscription_status, subscription_ends_at")
      .eq("id", user.id)
      .maybeSingle<ProfileRow>();

    logPayment(FN, "profile_loaded", {
      userId: user.id,
      subscriptionStatus: profile?.subscription_status ?? "none",
      hasPhone: !!(profile?.phone ?? user.phone),
    });

    if (isProfileAccessActive(profile?.subscription_status, profile?.subscription_ends_at)) {
      logPayment(FN, "subscription_already_active", {
        userId: user.id,
        status: profile?.subscription_status,
      }, "warn");
      return jsonResponse({ error: "Subscription already active" }, 409);
    }

    const phone = normalizeIndianPhone(profile?.phone ?? user.phone);
    const customerName = `${config.appName} User`;
    const customerEmail = user.email?.trim() || fallbackCustomerEmail(config, phone);

    const subscriptionId = `ev_${user.id.replace(/-/g, "").slice(0, 12)}_${Date.now()}`;
    const planDetails = buildPlanDetails(config);

    logPayment(FN, "creating_cashfree_subscription", {
      userId: user.id,
      subscriptionId,
      phoneLast4: phone.slice(-4),
      planDetails,
      authorizationAmount: config.cashfreeTrialAmount,
      firstChargeTime: firstRecurringChargeTime(),
    });

    const cashfree = await cashfreeRequest<CreateSubscriptionResponse>(
      config,
      "POST",
      "/subscriptions",
      {
        subscription_id: subscriptionId,
        customer_details: {
          customer_name: customerName,
          customer_email: customerEmail,
          customer_phone: phone,
        },
        plan_details: planDetails,
        authorization_details: {
          authorization_amount: config.cashfreeTrialAmount,
          authorization_amount_refund: false,
          payment_methods: ["upi"],
        },
        subscription_first_charge_time: firstRecurringChargeTime(),
        subscription_tags: {
          user_id: user.id,
          app: "evos",
          plan: "premium",
        },
      },
      crypto.randomUUID(),
    );

    logPayment(FN, "cashfree_subscription_created", {
      userId: user.id,
      subscriptionId: cashfree.subscription_id,
      cashfreeStatus: cashfree.subscription_status ?? "unknown",
      hasSessionId: !!cashfree.subscription_session_id,
    });

    await markProfilePendingMandate(
      serviceClient,
      user.id,
      cashfree.subscription_id,
      profile?.phone ?? user.phone ?? null,
    );

    logPayment(FN, "profile_marked_pending", {
      userId: user.id,
      subscriptionId: cashfree.subscription_id,
    });

    return jsonResponse({
      subscription_id: cashfree.subscription_id,
      subscription_session_id: cashfree.subscription_session_id,
      environment: config.cashfreeEnvironment,
      authorization_amount: config.cashfreeTrialAmount,
      recurring_amount: config.cashfreeRecurringAmount,
    });
  } catch (error) {
    logPaymentError(FN, "failed", error);
    return jsonResponse({ error: (error as Error).message }, 500);
  }
});
