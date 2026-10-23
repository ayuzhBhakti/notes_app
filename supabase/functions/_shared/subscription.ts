import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import type { ResolvedAppConfig } from "./app_config.ts";

export type PlanType = "trial" | "monthly";
export type PaymentStatus = "pending" | "success" | "failed";
export type ProfileSubscriptionStatus =
  | "none"
  | "pending"
  | "trial"
  | "active"
  | "cancelled"
  | "expired";

export interface ProfileRow {
  id: string;
  phone: string | null;
  subscription_status: ProfileSubscriptionStatus;
  subscription_ends_at: string | null;
  cashfree_subscription_id: string | null;
}

export interface RecordPaymentInput {
  userId: string;
  phone: string | null;
  paymentId: string;
  cashfreeSubscriptionId: string;
  amount: number;
  planType: PlanType;
  status: PaymentStatus;
  paidAt?: string | null;
  /**
   * False for a failed debit on a mandate that is not the one on the profile: the row is kept,
   * but the user may be paying on another mandate and must not be set to expired.
   */
  expireProfileOnFailure?: boolean;
}

const TRIAL_MS = 24 * 60 * 60 * 1000;

export function trialEndsAt(from = Date.now()): string {
  return new Date(from + TRIAL_MS).toISOString();
}

export function monthlyEndsAt(from = Date.now()): string {
  const date = new Date(from);
  date.setMonth(date.getMonth() + 1);
  return date.toISOString();
}

export function planEndsAt(planType: PlanType, from = Date.now()): string {
  return planType === "trial" ? trialEndsAt(from) : monthlyEndsAt(from);
}

export function profileStatusForPlan(
  planType: PlanType,
  paymentStatus: PaymentStatus,
): ProfileSubscriptionStatus {
  if (paymentStatus !== "success") {
    return "expired";
  }
  return planType === "trial" ? "trial" : "active";
}

export function isProfileAccessActive(
  status: string | null | undefined,
  endsAt: string | null | undefined,
): boolean {
  if (
    status !== "trial" &&
    status !== "active" &&
    status !== "cancelled"
  ) {
    return false;
  }
  if (!endsAt) {
    return status === "trial" || status === "active";
  }
  return new Date(endsAt) > new Date();
}

const CANCELLATION_STATUSES = new Set([
  "CANCELLED",
  "CUSTOMER_CANCELLED",
  "CUSTOMER_PAUSED",
]);

const EXPIRED_STATUSES = new Set([
  "EXPIRED",
  "COMPLETED",
  "LINK_EXPIRED",
]);

export function isCancellationStatus(status: string | undefined): boolean {
  return CANCELLATION_STATUSES.has(status?.toUpperCase() ?? "");
}

export function isExpiredStatus(status: string | undefined): boolean {
  return EXPIRED_STATUSES.has(status?.toUpperCase() ?? "");
}

export async function markSubscriptionCancelled(
  client: SupabaseClient,
  userId: string,
): Promise<void> {
  const { data: profile } = await client
    .from("profiles")
    .select("subscription_ends_at")
    .eq("id", userId)
    .maybeSingle();

  const endsAt = profile?.subscription_ends_at;
  const stillValid = endsAt ? new Date(endsAt) > new Date() : false;

  const { error } = await client
    .from("profiles")
    .update({
      subscription_status: stillValid ? "cancelled" : "expired",
    })
    .eq("id", userId);
  if (error) throw error;
}

export async function markSubscriptionExpired(
  client: SupabaseClient,
  userId: string,
): Promise<void> {
  const { error } = await client
    .from("profiles")
    .update({ subscription_status: "expired" })
    .eq("id", userId);
  if (error) throw error;
}

export function resolvePlanType(
  paymentType: string | undefined,
  amount: number,
  config: ResolvedAppConfig,
): PlanType {
  const normalized = paymentType?.toUpperCase() ?? "";
  if (normalized === "AUTH" || amount <= config.cashfreeTrialAmount) {
    return "trial";
  }
  return "monthly";
}

export function resolvePaymentId(
  payload: Record<string, unknown>,
  cashfreeSubscriptionId: string,
  eventType: string,
): string {
  const candidates = [
    payload.payment_id,
    payload.cf_payment_id,
    payload.cf_paymentId,
    payload.paymentId,
  ];
  for (const candidate of candidates) {
    if (typeof candidate === "string" && candidate.trim()) {
      return candidate.trim();
    }
  }
  return `${cashfreeSubscriptionId}:${eventType}:${Date.now()}`;
}

export async function findProfileByCashfreeSubscription(
  client: SupabaseClient,
  cashfreeSubscriptionId: string,
): Promise<ProfileRow | null> {
  const { data } = await client
    .from("profiles")
    .select("id, phone, subscription_status, subscription_ends_at, cashfree_subscription_id")
    .eq("cashfree_subscription_id", cashfreeSubscriptionId)
    .maybeSingle();
  return data as ProfileRow | null;
}

/**
 * The user a mandate belongs to, from the payment log. Used when the profile no longer points at
 * the mandate: a user who taps Try Now again gets a new id on the profile, while the old mandate
 * can still be debited.
 */
export async function findUserByLedgerSubscription(
  client: SupabaseClient,
  cashfreeSubscriptionId: string,
): Promise<string | null> {
  const { data } = await client
    .from("subscription_payments")
    .select("user_id")
    .eq("cashfree_subscription_id", cashfreeSubscriptionId)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  return (data?.user_id as string | undefined) ?? null;
}

export async function recordSubscriptionPayment(
  client: SupabaseClient,
  input: RecordPaymentInput,
): Promise<{ inserted: boolean; planEndsAt: string }> {
  const paidAt = input.paidAt ?? new Date().toISOString();
  const planEndsAtValue = planEndsAt(input.planType, Date.parse(paidAt));

  const { error: insertError } = await client
    .from("subscription_payments")
    .insert({
      user_id: input.userId,
      phone: input.phone,
      payment_id: input.paymentId,
      cashfree_subscription_id: input.cashfreeSubscriptionId,
      payment_method: "upi",
      amount: input.amount,
      plan_type: input.planType,
      status: input.status,
      paid_at: input.status === "success" ? paidAt : null,
      plan_ends_at: input.status === "success" ? planEndsAtValue : null,
    });

  if (insertError) {
    if (insertError.code === "23505") {
      return { inserted: false, planEndsAt: planEndsAtValue };
    }
    throw insertError;
  }

  if (input.status === "success") {
    await client
      .from("profiles")
      .update({
        subscription_status: profileStatusForPlan(input.planType, input.status),
        subscription_ends_at: planEndsAtValue,
        cashfree_subscription_id: input.cashfreeSubscriptionId,
      })
      .eq("id", input.userId);
  } else if (input.planType === "monthly" && input.expireProfileOnFailure !== false) {
    await client
      .from("profiles")
      .update({
        subscription_status: "expired",
      })
      .eq("id", input.userId);
  }

  return { inserted: true, planEndsAt: planEndsAtValue };
}

/** The profile row is made by a database trigger at sign-up; the upsert covers a missing one. */
export async function markProfilePendingMandate(
  client: SupabaseClient,
  userId: string,
  cashfreeSubscriptionId: string,
  phone: string | null = null,
): Promise<void> {
  const { data: existing } = await client
    .from("profiles")
    .select("id")
    .eq("id", userId)
    .maybeSingle();

  if (existing?.id) {
    const { error } = await client
      .from("profiles")
      .update({
        subscription_status: "pending",
        cashfree_subscription_id: cashfreeSubscriptionId,
      })
      .eq("id", userId);
    if (error) throw error;
    return;
  }

  const { error } = await client
    .from("profiles")
    .insert({
      id: userId,
      phone,
      subscription_status: "pending",
      cashfree_subscription_id: cashfreeSubscriptionId,
    });
  if (error) throw error;
}
