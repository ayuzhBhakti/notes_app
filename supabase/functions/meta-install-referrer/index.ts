// Decodes the ad behind a Meta (Facebook / Instagram) app-install ad click.
// The app sends the Play install referrer exactly as Play gave it; this
// decrypts Meta's part with the Install Referrer Decryption Key and returns
// the campaign, ad set and ad. It stores nothing.
//
// Deployed with verify_jwt = false: it runs on first launch, before sign-in.
//
//   POST {"referrer": "<full Play install referrer>"}
//   200 {"ad": {...}}            a Meta ad
//   200 {"ad": null}             any other referrer (organic, Google Ads, a link)
//   422 {"error": "decrypt_failed" | "other_app"}   final: the app stops asking
//   400 {"error": "bad_request"}                    final
//   500 {"error": "not_configured" | "failed"}      the app asks again on a later launch
//
// The key is the private app_config row meta_install_referrer_key (64 hex
// characters, Meta App Dashboard → Settings → Basic → Android), with the
// function secret META_INSTALL_REFERRER_KEY as a fallback. It is never
// logged, and neither is the referrer.

import { createServiceClient } from "../_shared/app_config.ts";
import {
  decodeMetaReferrer,
  isMetaReferrerSource,
  isValidKeyHex,
  parseReferrer,
} from "../_shared/meta_referrer.ts";
import { logPayment, logPaymentError } from "../_shared/logger.ts";

const FN = "meta-install-referrer";

// The Facebook app in android/app/src/main/res/values/analytics_keys.xml. A
// referrer for any other app is refused rather than decrypted.
const META_APP_ID = "2015134735846694";

// A Meta referrer is well under 2 KB. Anything far larger is not one.
const MAX_REFERRER_LENGTH = 8192;

// The function is called without a user token, so the key is cached rather
// than read from the database on every call.
const KEY_CACHE_MS = 60_000;
let cachedKey: { value: string; at: number } | null = null;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Only this one private row is read, never the rest of app_config. */
async function loadKey(): Promise<string> {
  if (cachedKey && Date.now() - cachedKey.at < KEY_CACHE_MS) return cachedKey.value;
  const { data, error } = await createServiceClient()
    .from("app_config")
    .select("value")
    .eq("key", "meta_install_referrer_key")
    .maybeSingle();
  if (error) throw new Error(`Failed to read the key: ${error.message}`);
  const fromTable = (data?.value as string | undefined)?.trim() ?? "";
  const value = fromTable || (Deno.env.get("META_INSTALL_REFERRER_KEY") ?? "").trim();
  // A blank key is not cached, so setting it takes effect at once.
  if (value) cachedKey = { value, at: Date.now() };
  return value;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  try {
    const body = await req.json().catch(() => null) as { referrer?: unknown } | null;
    const referrer = body?.referrer;
    if (typeof referrer !== "string" || referrer.length > MAX_REFERRER_LENGTH) {
      return json({ error: "bad_request" }, 400);
    }

    // Anything but a Meta ad click is answered without touching the database.
    if (!isMetaReferrerSource(parseReferrer(referrer).get("utm_source"))) {
      return json({ ad: null });
    }

    const keyHex = await loadKey();
    if (!isValidKeyHex(keyHex)) {
      // A 5xx, so installs made before the key is set are decoded later.
      logPayment(FN, "not_configured", {}, "error");
      return json({ error: "not_configured" }, 500);
    }

    const result = await decodeMetaReferrer(referrer, { appId: META_APP_ID, keyHex });
    switch (result.kind) {
      case "ad":
        logPayment(FN, "decoded", { hasAdId: result.ad.ad_id !== null });
        return json({ ad: result.ad });
      case "not_meta":
        return json({ ad: null });
      case "error":
        logPayment(FN, result.code, {}, "warn");
        return json({ error: result.code }, 422);
    }
  } catch (error) {
    logPaymentError(FN, "failed", error);
    return json({ error: "failed" }, 500);
  }
});
