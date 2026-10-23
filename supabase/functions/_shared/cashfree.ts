import type { ResolvedAppConfig } from "./app_config.ts";

const API_VERSION = "2025-01-01";

export type CashfreeEnvironment = "sandbox" | "production";

export function cashfreeBaseUrl(env: CashfreeEnvironment): string {
  return env === "production"
    ? "https://api.cashfree.com/pg"
    : "https://sandbox.cashfree.com/pg";
}

export function cashfreeHeaders(
  config: ResolvedAppConfig,
  idempotencyKey?: string,
  apiVersion: string = API_VERSION,
): HeadersInit {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    "x-api-version": apiVersion || API_VERSION,
    "x-client-id": config.cashfreeAppId,
    "x-client-secret": config.cashfreeSecretKey,
  };
  if (idempotencyKey) {
    headers["x-idempotency-key"] = idempotencyKey;
  }
  return headers;
}

export async function cashfreeRequest<T>(
  config: ResolvedAppConfig,
  method: string,
  path: string,
  body?: unknown,
  idempotencyKey?: string,
): Promise<T> {
  const response = await fetch(`${cashfreeBaseUrl(config.cashfreeEnvironment)}${path}`, {
    method,
    headers: cashfreeHeaders(config, idempotencyKey),
    body: body ? JSON.stringify(body) : undefined,
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message = payload?.message ??
      payload?.error?.message ??
      payload?.code ??
      (typeof payload === "object" && payload !== null && Object.keys(payload).length > 0
        ? JSON.stringify(payload)
        : response.statusText);
    throw new Error(`Cashfree ${method} ${path} failed (${response.status}): ${message}`);
  }
  return payload as T;
}

export function normalizeIndianPhone(phone: string | null | undefined): string {
  const digits = (phone ?? "").replace(/\D/g, "");
  if (digits.length >= 10) {
    return digits.slice(-10);
  }
  throw new Error("A valid Indian phone number is required");
}

/**
 * Cashfree wants an email for every customer and a phone sign-in has none, so one is made from
 * the number on a domain the business owns (`customer_email_domain` in app_config).
 */
export function fallbackCustomerEmail(config: ResolvedAppConfig, phone: string): string {
  if (!config.customerEmailDomain) {
    throw new Error("customer_email_domain is not set in app_config");
  }
  return `user+${phone}@${config.customerEmailDomain}`;
}

export async function verifyCashfreeWebhookSignature(
  config: ResolvedAppConfig,
  rawBody: string,
  timestamp: string | null,
  signature: string | null,
): Promise<boolean> {
  if (!timestamp || !signature) return false;

  const secret = config.cashfreeSecretKey;
  if (!secret) return false;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signatureData = `${timestamp}${rawBody}`;
  const digest = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(signatureData),
  );

  const computed = btoa(String.fromCharCode(...new Uint8Array(digest)));
  return computed === signature;
}

export function buildPlanDetails(config: ResolvedAppConfig) {
  // A plan created in the Cashfree dashboard, when its id is in app_config. Otherwise the plan
  // is described inline from the amounts in app_config.
  if (config.cashfreePlanId) {
    return { plan_id: config.cashfreePlanId };
  }
  return {
    plan_name: config.planName,
    plan_type: "PERIODIC",
    plan_amount: config.cashfreeRecurringAmount,
    plan_max_amount: config.cashfreeRecurringAmount,
    plan_intervals: 1,
    plan_interval_type: "MONTH",
    plan_currency: "INR",
    plan_note: `₹${config.cashfreeRecurringAmount}/month after 24-hour trial`,
  };
}
