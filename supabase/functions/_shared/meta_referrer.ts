// Decodes the ad a Meta (Facebook / Instagram) app-install ad put in the Play
// install referrer. Meta encrypts it, so it can only be read here, with the
// Install Referrer Decryption Key, which never ships in the app.
//
// What Meta sends: utm_source=apps.facebook.com (or apps.instagram.com) and
// utm_content={"app":<app id>,"t":<time>,"source":{"data":"<hex>","nonce":"<hex>"}}.
// data is AES-256-GCM ciphertext with the 16-byte tag at its end.
// https://developers.facebook.com/docs/app-ads/install-referrer

export const META_REFERRER_SOURCES: ReadonlySet<string> = new Set([
  "apps.facebook.com",
  "apps.instagram.com",
]);

/** The ad, in today's names. Meta's payload uses the old ones (see readMetaAd). */
export interface MetaAd {
  campaign: string | null;
  campaign_id: string | null;
  adset: string | null;
  adset_id: string | null;
  ad: string | null;
  ad_id: string | null;
  account_id: string | null;
  publisher_platform: string | null;
  platform_position: string | null;
  is_instagram: boolean | null;
}

export interface MetaEnvelope {
  app: string;
  data: string;
  nonce: string;
}

export type MetaDecodeError = "decrypt_failed" | "other_app";

export type MetaDecodeResult =
  | { kind: "ad"; ad: MetaAd }
  | { kind: "not_meta" }
  | { kind: "error"; code: MetaDecodeError };

const KEY_HEX = /^[0-9a-fA-F]{64}$/;
const HEX = /^(?:[0-9a-fA-F]{2})+$/;
const GCM_TAG_BYTES = 16;

export function isValidKeyHex(keyHex: string): boolean {
  return KEY_HEX.test(keyHex);
}

/** The referrer is a query string; some browsers hand it over still encoded. */
export function parseReferrer(referrer: string): URLSearchParams {
  const text = referrer.includes("=") ? referrer : safeDecode(referrer);
  return new URLSearchParams(text);
}

function safeDecode(text: string): string {
  try {
    return decodeURIComponent(text);
  } catch (_) {
    return text;
  }
}

export function isMetaReferrerSource(source: string | null | undefined): boolean {
  return META_REFERRER_SOURCES.has(source?.trim().toLowerCase() ?? "");
}

/**
 * Reads a number or string field from the raw JSON text, as text. Ids are
 * up to 18 digits, past the 2^53 a JS number holds exactly, so JSON.parse
 * would quietly change them.
 */
function rawId(json: string, key: string): string | null {
  const match = json.match(new RegExp(`"${key}"\\s*:\\s*"?(\\d{1,30})"?`));
  return match ? match[1] : null;
}

function stringField(record: Record<string, unknown>, key: string): string | null {
  const value = record[key];
  return typeof value === "string" && value.trim() !== "" ? value.trim() : null;
}

function parseObject(json: string): Record<string, unknown> | null {
  try {
    const value = JSON.parse(json);
    return value !== null && typeof value === "object" && !Array.isArray(value)
      ? value as Record<string, unknown>
      : null;
  } catch (_) {
    return null;
  }
}

/** utm_content of a Meta referrer. Null when it is not the expected shape. */
export function readMetaEnvelope(utmContent: string): MetaEnvelope | null {
  const record = parseObject(utmContent);
  const source = record?.source;
  if (!record || source === null || typeof source !== "object") return null;
  const data = stringField(source as Record<string, unknown>, "data");
  const nonce = stringField(source as Record<string, unknown>, "nonce");
  const app = rawId(utmContent, "app");
  if (!data || !nonce || !app) return null;
  return { app, data, nonce };
}

/**
 * Meta's payload keeps the ad's pre-2014 names: adgroup = ad,
 * campaign = ad set, campaign_group = campaign.
 */
export function readMetaAd(plaintext: string): MetaAd | null {
  const record = parseObject(plaintext);
  if (!record) return null;
  const isInstagram = record.is_instagram;
  return {
    campaign: stringField(record, "campaign_group_name"),
    campaign_id: rawId(plaintext, "campaign_group_id"),
    adset: stringField(record, "campaign_name"),
    adset_id: rawId(plaintext, "campaign_id"),
    ad: stringField(record, "adgroup_name"),
    ad_id: rawId(plaintext, "ad_id") ?? rawId(plaintext, "adgroup_id"),
    account_id: rawId(plaintext, "account_id"),
    publisher_platform: stringField(record, "publisher_platform"),
    platform_position: stringField(record, "platform_position"),
    is_instagram: typeof isInstagram === "boolean" ? isInstagram : null,
  };
}

function hexToBytes(hex: string): Uint8Array<ArrayBuffer> {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return bytes;
}

/**
 * AES-256-GCM. WebCrypto expects the tag after the ciphertext, which is how
 * Meta lays out `data`. Null for anything that does not open: wrong key,
 * tampered or cut data, or malformed hex.
 */
export async function decryptMetaData(
  keyHex: string,
  dataHex: string,
  nonceHex: string,
): Promise<string | null> {
  if (!isValidKeyHex(keyHex) || !HEX.test(dataHex) || !HEX.test(nonceHex)) return null;
  if (dataHex.length / 2 <= GCM_TAG_BYTES) return null;
  try {
    const key = await crypto.subtle.importKey("raw", hexToBytes(keyHex), "AES-GCM", false, [
      "decrypt",
    ]);
    const plain = await crypto.subtle.decrypt(
      { name: "AES-GCM", iv: hexToBytes(nonceHex), tagLength: GCM_TAG_BYTES * 8 },
      key,
      hexToBytes(dataHex),
    );
    return new TextDecoder().decode(plain);
  } catch (_) {
    return null;
  }
}

export async function decodeMetaReferrer(
  referrer: string,
  options: { appId: string; keyHex: string },
): Promise<MetaDecodeResult> {
  const params = parseReferrer(referrer);
  if (!isMetaReferrerSource(params.get("utm_source"))) return { kind: "not_meta" };

  const envelope = readMetaEnvelope(params.get("utm_content") ?? "");
  if (!envelope) return { kind: "error", code: "decrypt_failed" };
  if (envelope.app !== options.appId) return { kind: "error", code: "other_app" };

  const plaintext = await decryptMetaData(options.keyHex, envelope.data, envelope.nonce);
  const ad = plaintext === null ? null : readMetaAd(plaintext);
  if (!ad) return { kind: "error", code: "decrypt_failed" };
  return { kind: "ad", ad };
}
