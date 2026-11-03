// Meta (Facebook) Conversions API for App Events: the server-side Purchase event for the real
// ₹299 monthly debit, which happens while the app is closed, so the client SDK can never log it.
// The ₹3 trial is still logged client-side, as Meta's StartTrial event (AnalyticsChannel.kt): a
// trial is never sent here too, so it is never double-counted as Purchase revenue.
//
// Sending is best-effort: a failed or slow call is logged and dropped, and never fails the
// payment work around it (same convention as _shared/mixpanel.ts).

import { logPayment } from "./logger.ts";

const API_VERSION = "v21.0";
const TIMEOUT_MS = 3000;

export interface MetaPurchaseEventInput {
  accessToken: string;
  datasetId: string;
  /** Facebook SDK per-app-install GUID (profiles.meta_anon_id). No event without it: with
   * nothing to match the install to, Meta cannot attribute the revenue to an ad. */
  anonId: string | null;
  amount: number;
  currency: string;
  /** The Cashfree payment id: de-duplicates against a repeated webhook delivery. */
  eventId: string;
  eventTime?: number;
}

type FetchLike = (url: string | URL | Request, init?: RequestInit) => Promise<Response>;

/**
 * True once Meta's dataset events endpoint accepted the event. Never throws: a missing access
 * token, dataset id or anon id, a network error, or a refusal all return false.
 */
export async function sendMetaPurchaseEvent(
  input: MetaPurchaseEventInput,
  fetchImpl: FetchLike = fetch,
): Promise<boolean> {
  if (!input.accessToken || !input.datasetId || !input.anonId) return false;
  try {
    const url = `https://graph.facebook.com/${API_VERSION}/${input.datasetId}/events` +
      `?access_token=${encodeURIComponent(input.accessToken)}`;
    const body = {
      data: [
        {
          event_name: "Purchase",
          event_time: input.eventTime ?? Math.floor(Date.now() / 1000),
          event_id: input.eventId,
          action_source: "app",
          user_data: { anon_id: input.anonId },
          custom_data: {
            currency: input.currency,
            value: input.amount.toFixed(2),
          },
          app_data: {
            // No device-level ad id is collected (see profiles.meta_anon_id); matching relies on
            // anon_id alone, so advertiser-level tracking is reported off.
            advertiser_tracking_enabled: 0,
            application_tracking_enabled: 1,
            // Fixed 16-slot Android device descriptor Meta's docs ask for. Only the package name
            // is known server-side; OS version (slot 4) is marked required by Meta's validator
            // (confirmed 2026-11-02: a blank value is refused with error_subcode 2804043), so a
            // placeholder goes there. Every other slot is left blank rather than guessed.
            extinfo: [
              "a2",
              "com.spacewire.evos",
              "",
              "",
              "13",
              "",
              "",
              "",
              "",
              "",
              "",
              "",
              "",
              "",
              "",
              "",
            ],
          },
        },
      ],
    };
    const response = await fetchImpl(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    const json = await response.json().catch(() => null) as
      | { events_received?: number }
      | null;
    return response.ok && (json?.events_received ?? 0) > 0;
  } catch (_) {
    return false;
  }
}

/** Sends the Purchase event and logs the outcome. Never throws. */
export async function trackMetaPurchase(
  fn: string,
  input: MetaPurchaseEventInput,
  fetchImpl: FetchLike = fetch,
): Promise<void> {
  if (!input.accessToken || !input.datasetId) return;
  try {
    const sent = await sendMetaPurchaseEvent(input, fetchImpl);
    logPayment(fn, "meta_capi", { eventId: input.eventId, sent }, sent ? "info" : "warn");
  } catch (_) {
    logPayment(fn, "meta_capi", { eventId: input.eventId, sent: false }, "warn");
  }
}
