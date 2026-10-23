// Supabase Send SMS Hook -> Fast2SMS (DLT OTP route)
//
// Supabase Auth generates and validates the OTP. This hook only DELIVERS the
// SMS: it verifies the webhook signature, extracts { user.phone, sms.otp },
// and forwards the code to Fast2SMS using the DLT route.
//
// Settings are rows of the app_config table, the same three keys as CashAlert:
//   fast2sms                 the Fast2SMS API key
//   fast2sms_dlt_sender_id   the DLT sender id
//   fast2sms_dlt_te_id       the template (message) id
// plus send_sms_hook_secret, which the dashboard shows when the hook is saved.
// A function secret (FAST2SMS_API_KEY, FAST2SMS_SENDER_ID, FAST2SMS_MESSAGE_ID,
// SEND_SMS_HOOK_SECRET) is used only when its row is empty.

import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";
import { type AppConfigMap, loadConfigMap } from "../_shared/app_config.ts";

const FAST2SMS_ENDPOINT = "https://www.fast2sms.com/dev/bulkV2";

interface SmsHookPayload {
  user: { phone: string };
  sms: { otp: string };
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function pick(config: AppConfigMap, key: string, envKey: string): string {
  return config[key]?.trim() || Deno.env.get(envKey)?.trim() || "";
}

function readHookSecret(config: AppConfigMap): string {
  const rawSecret = pick(config, "send_sms_hook_secret", "SEND_SMS_HOOK_SECRET");
  return rawSecret
    .trim()
    .replace(/^v1,whsec_/, "")
    .replace(/^whsec_/, "")
    .trim();
}

function readSmsSecrets(config: AppConfigMap) {
  const apiKey = pick(config, "fast2sms", "FAST2SMS_API_KEY");
  const senderId = pick(config, "fast2sms_dlt_sender_id", "FAST2SMS_SENDER_ID");
  const templateId = pick(config, "fast2sms_dlt_te_id", "FAST2SMS_MESSAGE_ID");

  if (!apiKey || !senderId || !templateId) {
    throw new Error(
      "Fast2SMS settings missing. Fill fast2sms, fast2sms_dlt_sender_id and fast2sms_dlt_te_id in app_config.",
    );
  }

  return { apiKey, senderId, templateId };
}

Deno.serve(async (req) => {
  try {
    const config = await loadConfigMap();
    const hookSecret = readHookSecret(config);
    if (!hookSecret) {
      console.error("sms-hook: send_sms_hook_secret is not set in app_config");
      return jsonResponse({ error: { message: "SMS hook secret not configured" } }, 500);
    }

    const payload = await req.text();
    const headers = Object.fromEntries(req.headers);

    const wh = new Webhook(hookSecret);
    const { user, sms } = wh.verify(payload, headers) as SmsHookPayload;

    // Fast2SMS's DLT route reaches Indian numbers only. Anything else is
    // refused in words the app recognises, rather than sent and lost.
    const digits = user.phone.replace(/\D/g, "");
    if (!digits.startsWith("91") || digits.length !== 12) {
      return jsonResponse(
        { error: { http_code: 422, message: "sms_country_not_supported" } },
        422,
      );
    }
    const number = digits.slice(2);
    const smsSecrets = readSmsSecrets(config);

    const params = new URLSearchParams({
      route: "dlt",
      sender_id: smsSecrets.senderId,
      message: smsSecrets.templateId,
      variables_values: sms.otp,
      flash: "0",
      numbers: number,
    });

    const res = await fetch(FAST2SMS_ENDPOINT, {
      method: "POST",
      headers: {
        "authorization": smsSecrets.apiKey,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: params.toString(),
    });

    const body = await res.json().catch(() => ({}));

    if (!res.ok || body?.return === false) {
      console.error("Fast2SMS error:", res.status, body);
      return jsonResponse(
        { error: { message: body?.message ?? "Failed to send SMS via Fast2SMS" } },
        502,
      );
    }

    console.log("Fast2SMS sent OK");
    return jsonResponse({});
  } catch (err) {
    const message = (err as Error).message ?? "SMS hook failed";
    console.error("sms-hook failure:", message);

    if (message.includes("No matching signature") || message.includes("Invalid signature")) {
      return jsonResponse({ error: { message: "Invalid SMS hook signature" } }, 401);
    }

    return jsonResponse({ error: { message } }, 500);
  }
});
