// Tests for the per-source write allowlist and validation.
// Run with: deno test supabase/functions/_shared/source_config.test.ts
// (Deno is not installed in the build machine used so far; written for CI.)

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { buildSourceRow, coerceColumn, normalizeSource } from "./source_config.ts";

Deno.test("normalizeSource lowercases and rejects junk", () => {
  assertEquals(normalizeSource("FilmyFace"), "filmyface");
  assertEquals(normalizeSource("  Google-Play "), "google-play");
  assertEquals(normalizeSource(""), null);
  assertEquals(normalizeSource("has space"), null);
  assertEquals(normalizeSource(42 as unknown), null);
});

Deno.test("coerceColumn: secret keys are not columns, so they are rejected", () => {
  for (const key of ["cashfree_secret_key", "fast2sms", "admin_panel_secret", "is_public"]) {
    const result = coerceColumn(key, "x");
    assertEquals("error" in result, true);
  }
});

Deno.test("coerceColumn: null inherits, empty string overrides", () => {
  assertEquals(coerceColumn("app_name", null), { value: null });
  assertEquals(coerceColumn("app_name", undefined), { value: null });
  assertEquals(coerceColumn("paywall_subtitle", ""), { value: "" });
});

Deno.test("coerceColumn: url must be https", () => {
  assertEquals("error" in coerceColumn("app_logo_url", "http://x.com/a.png"), true);
  assertEquals(coerceColumn("app_logo_url", "https://x.com/a.png"), {
    value: "https://x.com/a.png",
  });
});

Deno.test("coerceColumn: colour accepts #RRGGBB and adds the hash", () => {
  assertEquals(coerceColumn("theme_color", "E11D48"), { value: "#E11D48" });
  assertEquals("error" in coerceColumn("theme_color", "red"), true);
});

Deno.test("coerceColumn: bool coerces common forms", () => {
  assertEquals(coerceColumn("paywall_show_strike_price", "true"), { value: true });
  assertEquals(coerceColumn("paywall_show_strike_price", false), { value: false });
  assertEquals(coerceColumn("paywall_show_strike_price", ""), { value: null });
});

Deno.test("coerceColumn: urlList drops blanks and requires https", () => {
  assertEquals(coerceColumn("login_slide_images", "https://a.com/1.png | https://a.com/2.png"), {
    value: "https://a.com/1.png|https://a.com/2.png",
  });
  assertEquals("error" in coerceColumn("login_slide_images", "https://a.com/1.png|ftp://x"), true);
});

Deno.test("buildSourceRow: unknown keys in the payload are ignored, not written", () => {
  const built = buildSourceRow({
    source: "Partner",
    is_active: true,
    app_name: "Partner",
    cashfree_secret_key: "leaked", // not a column -> never reaches the row
    theme_color: "123456",
  });
  if ("error" in built) throw new Error(built.error);
  assertEquals(built.row.source, "partner");
  assertEquals(built.row.app_name, "Partner");
  assertEquals(built.row.theme_color, "#123456");
  assertEquals("cashfree_secret_key" in built.row, false);
  // A column not given is set to null (inherit), not left undefined.
  assertEquals(built.row.paywall_subtitle, null);
});

Deno.test("coerceColumn: amount must be a positive number", () => {
  assertEquals(coerceColumn("cashfree_trial_amount", "3"), { value: "3" });
  assertEquals(coerceColumn("cashfree_recurring_amount", "299.50"), { value: "299.50" });
  assertEquals("error" in coerceColumn("cashfree_trial_amount", "0"), true);
  assertEquals("error" in coerceColumn("cashfree_trial_amount", "-5"), true);
  assertEquals("error" in coerceColumn("cashfree_recurring_amount", "abc"), true);
  // Empty means "inherit the global price" (null), never a stored "" — that
  // would read as global on the server but as the app default on the paywall.
  assertEquals(coerceColumn("cashfree_trial_amount", ""), { value: null });
  assertEquals(coerceColumn("cashfree_recurring_amount", "   "), { value: null });
});

Deno.test("buildSourceRow: pricing columns are allowlisted and validated", () => {
  const built = buildSourceRow({
    source: "partner",
    plan_name: "Partner Monthly",
    cashfree_plan_id: "plan_123",
    cashfree_trial_amount: "5",
    cashfree_recurring_amount: "399",
  });
  if ("error" in built) throw new Error(built.error);
  assertEquals(built.row.plan_name, "Partner Monthly");
  assertEquals(built.row.cashfree_trial_amount, "5");
  assertEquals(built.row.cashfree_recurring_amount, "399");
});

Deno.test("buildSourceRow: an invalid value fails the whole upsert", () => {
  const built = buildSourceRow({ source: "partner", app_logo_url: "http://x" });
  assertEquals("error" in built, true);
});
