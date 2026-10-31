// Mixpanel events sent by the backend: payments the app never sees (the
// monthly debit happens while it is closed), cancellations and expiries.
//
// Every event carries the user's ad, read from their profile row, so server
// events can be broken down by campaign, ad set and ad exactly like the
// app's. distinct_id is the Supabase user id, the id the app passes to
// Mixpanel's identify on sign-in, so both land on the same person.
//
// Sending is best-effort: a failed or slow Mixpanel call is logged and
// dropped, and never fails the payment work around it.

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import type { PaymentStatus, PlanType } from "./subscription.ts";
import { logPayment } from "./logger.ts";

const TRACK_URL = "https://api.mixpanel.com/track";
const TIMEOUT_MS = 3000;
const INSERT_ID_MAX = 36;

/** The ad columns on public.profiles, named as the app's super properties. */
export const ATTRIBUTION_COLUMNS = [
  "install_source",
  "utm_source",
  "utm_medium",
  "utm_campaign",
  "utm_term",
  "utm_content",
  "campaign_id",
  "adset_id",
  "ad_id",
] as const;

export type AttributionColumn = typeof ATTRIBUTION_COLUMNS[number];
export type UserAttribution = Partial<Record<AttributionColumn, string | null>>;

/** `manual` exists in other apps' reports; Evos has no manual payment. */
export type ServerPaymentType = "trial" | "auto_renewal" | "retry";

export interface ServerEvent {
  event: string;
  properties: Record<string, unknown>;
}

type FetchLike = (url: string | URL | Request, init?: RequestInit) => Promise<Response>;

/** A debit that follows a failed one on the same mandate is a retry. */
export function paymentTypeFor(
  planType: PlanType,
  previousStatus: PaymentStatus | null,
): ServerPaymentType {
  if (planType === "trial") return "trial";
  return previousStatus === "failed" ? "retry" : "auto_renewal";
}

/**
 * Mixpanel drops a second event with the same $insert_id, which makes a
 * repeated webhook harmless. It allows 36 characters of [A-Za-z0-9-].
 */
export function insertIdFor(raw: string): string {
  const clean = raw.replace(/[^A-Za-z0-9-]/g, "-");
  return clean.length > INSERT_ID_MAX ? clean.slice(-INSERT_ID_MAX) : clean;
}

export function buildServerEvent(input: {
  token: string;
  event: string;
  userId: string;
  insertId: string;
  time: number;
  properties: Record<string, unknown>;
  attribution: UserAttribution;
}): ServerEvent {
  const ad: Record<string, string> = {};
  for (const column of ATTRIBUTION_COLUMNS) {
    const value = input.attribution[column]?.trim();
    if (value) ad[column] = value;
  }
  return {
    event: input.event,
    properties: {
      ...ad,
      ...input.properties,
      // Last, so nothing above can send the event to another person or project.
      token: input.token,
      distinct_id: input.userId,
      time: input.time,
      $insert_id: insertIdFor(input.insertId),
      event_source: "server",
    },
  };
}

/** True when Mixpanel accepted the batch. Never throws. */
export async function sendServerEvents(
  events: ServerEvent[],
  fetchImpl: FetchLike = fetch,
): Promise<boolean> {
  try {
    const response = await fetchImpl(TRACK_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "text/plain" },
      body: JSON.stringify(events),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    const text = (await response.text()).trim();
    return response.ok && text === "1";
  } catch (_) {
    return false;
  }
}

export async function loadUserAttribution(
  client: SupabaseClient,
  userId: string,
): Promise<UserAttribution> {
  try {
    const { data } = await client
      .from("profiles")
      .select(ATTRIBUTION_COLUMNS.join(","))
      .eq("id", userId)
      .maybeSingle();
    return (data as unknown as UserAttribution | null) ?? {};
  } catch (_) {
    // The event still goes, without the ad.
    return {};
  }
}

/**
 * The status of the payment before [paymentId] on the same mandate, to tell a
 * retry from a scheduled renewal.
 */
export async function previousPaymentStatus(
  client: SupabaseClient,
  cashfreeSubscriptionId: string,
  paymentId: string,
): Promise<PaymentStatus | null> {
  try {
    const { data } = await client
      .from("subscription_payments")
      .select("status")
      .eq("cashfree_subscription_id", cashfreeSubscriptionId)
      .neq("payment_id", paymentId)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    return (data?.status as PaymentStatus | undefined) ?? null;
  } catch (_) {
    return null;
  }
}

/**
 * Sends one event for [userId] with their ad attached. Does nothing without a
 * token (the private app_config row mixpanel_token). Never throws.
 */
export async function trackUserEvent(
  client: SupabaseClient,
  token: string,
  input: {
    fn: string;
    event: string;
    userId: string;
    insertId: string;
    properties: Record<string, unknown>;
    time?: number;
  },
): Promise<void> {
  if (!token) return;
  try {
    const attribution = await loadUserAttribution(client, input.userId);
    const sent = await sendServerEvents([
      buildServerEvent({
        token,
        event: input.event,
        userId: input.userId,
        insertId: input.insertId,
        time: input.time ?? Math.floor(Date.now() / 1000),
        properties: input.properties,
        attribution,
      }),
    ]);
    logPayment(input.fn, "mixpanel", { event: input.event, sent }, sent ? "info" : "warn");
  } catch (_) {
    logPayment(input.fn, "mixpanel", { event: input.event, sent: false }, "warn");
  }
}
