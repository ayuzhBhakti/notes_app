// Tests for decoding Meta's encrypted Play install referrer.
// Run with: deno test supabase/functions/_shared/meta_referrer.test.ts
//
// Every key here is generated per run. The real Install Referrer Decryption
// Key never appears in this repository.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  decodeMetaReferrer,
  decryptMetaData,
  isMetaReferrerSource,
  parseReferrer,
  readMetaAd,
  readMetaEnvelope,
} from "./meta_referrer.ts";

const APP_ID = "2015134735846694";

function toHex(bytes: Uint8Array): string {
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

function randomHex(length: number): string {
  return toHex(crypto.getRandomValues(new Uint8Array(length)));
}

function hexBytes(hex: string): Uint8Array<ArrayBuffer> {
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) out[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  return out;
}

/** Encrypts like Meta: AES-256-GCM, ciphertext followed by the 16-byte tag, hex. */
async function encrypt(keyHex: string, nonceHex: string, plaintext: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", hexBytes(keyHex), "AES-GCM", false, [
    "encrypt",
  ]);
  const sealed = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv: hexBytes(nonceHex) },
    key,
    new TextEncoder().encode(plaintext),
  );
  return toHex(new Uint8Array(sealed));
}

// Ids are bare JSON numbers on purpose: 18 digits is past what a JS number
// holds exactly, so reading them through JSON.parse would change them.
const PLAINTEXT = `{"ad_id":120212345678901234,"adgroup_id":120212345678901234,` +
  `"adgroup_name":"Evos_Reel_Hindi_30s","campaign_id":120298765432109876,` +
  `"campaign_name":"Broad_18-45","campaign_group_id":120211112222333344,` +
  `"campaign_group_name":"Evos_AppInstalls_Hindi","account_id":987654321012345,` +
  `"ad_objective_name":"APP_INSTALLS","is_instagram":true,` +
  `"publisher_platform":"instagram","platform_position":"instagram_reels"}`;

async function metaReferrer(
  keyHex: string,
  options: { app?: string; plaintext?: string; source?: string } = {},
): Promise<string> {
  const nonce = randomHex(12);
  const data = await encrypt(keyHex, nonce, options.plaintext ?? PLAINTEXT);
  const content = `{"app":${options.app ?? APP_ID},"t":1761900000,` +
    `"source":{"data":"${data}","nonce":"${nonce}"}}`;
  return `utm_source=${options.source ?? "apps.facebook.com"}&utm_campaign=fb4a` +
    `&utm_content=${encodeURIComponent(content)}`;
}

Deno.test("parseReferrer reads a plain and a wholly encoded referrer", () => {
  assertEquals(parseReferrer("utm_source=mail&utm_medium=email").get("utm_source"), "mail");
  assertEquals(
    parseReferrer("utm_source%3Dmail%26utm_medium%3Demail").get("utm_medium"),
    "email",
  );
  assertEquals(parseReferrer("").get("utm_source"), null);
});

Deno.test("isMetaReferrerSource accepts only Meta's two hosts", () => {
  assertEquals(isMetaReferrerSource("apps.facebook.com"), true);
  assertEquals(isMetaReferrerSource("apps.instagram.com"), true);
  assertEquals(isMetaReferrerSource("APPS.FACEBOOK.COM"), true);
  assertEquals(isMetaReferrerSource("facebook"), false);
  assertEquals(isMetaReferrerSource(null), false);
});

Deno.test("readMetaEnvelope keeps the app id as text and finds data and nonce", () => {
  const envelope = readMetaEnvelope(
    `{"app":2015134735846694,"t":1,"source":{"data":"ab12","nonce":"cd34"}}`,
  );
  assertEquals(envelope, { app: APP_ID, data: "ab12", nonce: "cd34" });
  assertEquals(readMetaEnvelope("not json"), null);
  assertEquals(readMetaEnvelope(`{"app":1,"source":{}}`), null);
});

Deno.test("readMetaAd maps Meta's old names and keeps 18-digit ids exact", () => {
  assertEquals(readMetaAd(PLAINTEXT), {
    campaign: "Evos_AppInstalls_Hindi",
    campaign_id: "120211112222333344",
    adset: "Broad_18-45",
    adset_id: "120298765432109876",
    ad: "Evos_Reel_Hindi_30s",
    ad_id: "120212345678901234",
    account_id: "987654321012345",
    publisher_platform: "instagram",
    platform_position: "instagram_reels",
    is_instagram: true,
  });
});

Deno.test("readMetaAd falls back to adgroup_id when ad_id is absent", () => {
  const ad = readMetaAd(`{"adgroup_id":"120200000000000001","adgroup_name":"A"}`);
  assertEquals(ad?.ad_id, "120200000000000001");
  assertEquals(ad?.ad, "A");
  assertEquals(ad?.campaign, null);
});

Deno.test("decryptMetaData opens data whose last 16 bytes are the GCM tag", async () => {
  const key = randomHex(32);
  const nonce = randomHex(12);
  const data = await encrypt(key, nonce, "hello");
  assertEquals(await decryptMetaData(key, data, nonce), "hello");
});

Deno.test("decryptMetaData returns null for a wrong key or tampered data", async () => {
  const key = randomHex(32);
  const nonce = randomHex(12);
  const data = await encrypt(key, nonce, "hello");
  assertEquals(await decryptMetaData(randomHex(32), data, nonce), null);
  const flipped = (data[0] === "0" ? "1" : "0") + data.slice(1);
  assertEquals(await decryptMetaData(key, flipped, nonce), null);
  assertEquals(await decryptMetaData(key, "zz", nonce), null);
});

Deno.test("decodeMetaReferrer returns the ad for a Meta install", async () => {
  const key = randomHex(32);
  const result = await decodeMetaReferrer(await metaReferrer(key), { appId: APP_ID, keyHex: key });
  assertEquals(result.kind, "ad");
  if (result.kind === "ad") {
    assertEquals(result.ad.ad_id, "120212345678901234");
    assertEquals(result.ad.campaign, "Evos_AppInstalls_Hindi");
  }
});

Deno.test("decodeMetaReferrer accepts apps.instagram.com", async () => {
  const key = randomHex(32);
  const referrer = await metaReferrer(key, { source: "apps.instagram.com" });
  const result = await decodeMetaReferrer(referrer, { appId: APP_ID, keyHex: key });
  assertEquals(result.kind, "ad");
});

Deno.test("decodeMetaReferrer: any other referrer is not a Meta ad", async () => {
  for (const referrer of ["", "utm_source=google-play&utm_medium=organic", "gclid=abc"]) {
    const result = await decodeMetaReferrer(referrer, { appId: APP_ID, keyHex: randomHex(32) });
    assertEquals(result, { kind: "not_meta" });
  }
});

Deno.test("decodeMetaReferrer: another app's referrer is other_app", async () => {
  const key = randomHex(32);
  const referrer = await metaReferrer(key, { app: "1111111111111111" });
  const result = await decodeMetaReferrer(referrer, { appId: APP_ID, keyHex: key });
  assertEquals(result, { kind: "error", code: "other_app" });
});

Deno.test("decodeMetaReferrer: wrong key, cut nonce or junk content is decrypt_failed", async () => {
  const key = randomHex(32);
  const referrer = await metaReferrer(key);
  assertEquals(
    await decodeMetaReferrer(referrer, { appId: APP_ID, keyHex: randomHex(32) }),
    { kind: "error", code: "decrypt_failed" },
  );
  // What a 255-character copy of the referrer looks like: the nonce is gone.
  assertEquals(
    await decodeMetaReferrer(referrer.slice(0, 255), { appId: APP_ID, keyHex: key }),
    { kind: "error", code: "decrypt_failed" },
  );
  assertEquals(
    await decodeMetaReferrer("utm_source=apps.facebook.com&utm_content=x", {
      appId: APP_ID,
      keyHex: key,
    }),
    { kind: "error", code: "decrypt_failed" },
  );
});
