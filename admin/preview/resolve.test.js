// Run: deno test admin/preview/resolve.test.js
// The preview must read settings exactly as the app's RemoteConfig.fromRows
// (lib/models/remote_config.dart) does, or the owner is shown a screen the
// phone will never draw. Each test pins one of those rules.

import { assertEquals } from "jsr:@std/assert@1";
import {
  formatRupees,
  iconFor,
  mergeRows,
  parseColor,
  previewCardSize,
  resolveConfig,
  starIcons,
} from "./resolve.js";

Deno.test("no rows gives the app's own defaults", () => {
  const c = resolveConfig({});
  assertEquals(c.appName, "Evos");
  assertEquals(c.logoUrl, null);
  assertEquals(c.seedColor, "#6D28D9");
  assertEquals(c.paywallTitlePrefix, "1-Day");
  assertEquals(c.paywallTitleSuffix, "Trial");
  assertEquals(c.badgeText, "₹3");
  assertEquals(c.features, ["Full access", "Cancel anytime", "Secure UPI AutoPay"]);
  assertEquals(c.showStrikePrice, false);
  assertEquals(c.accentColor, null);
  assertEquals(c.ctaText, "Try Now");
  assertEquals(c.upiSelectText, "Select UPI App");
  assertEquals(c.upiSheetTitle, "Pay with UPI AutoPay");
  assertEquals(c.loginSlides, []);
  assertEquals(c.webUrl, null);
  assertEquals(c.videoAspectRatio, 1);
  assertEquals(
    c.autoPayStatement,
    "₹3 today for the first 24 hours, then ₹299 every month by UPI AutoPay. Cancel any time in your UPI app.",
  );
});

Deno.test("text() keys fall back on blank, optional() keys keep blank", () => {
  const c = resolveConfig({
    app_name: "  ",
    paywall_cta_text: "",
    paywall_title_prefix: "",
    paywall_title_suffix: " ",
  });
  assertEquals(c.appName, "Evos");
  assertEquals(c.ctaText, "Try Now");
  assertEquals(c.paywallTitlePrefix, "");
  assertEquals(c.paywallTitleSuffix, "");
});

Deno.test("a set badge replaces the trial price in the pill", () => {
  assertEquals(resolveConfig({ paywall_title_badge: "FREE" }).badgeText, "FREE");
  assertEquals(resolveConfig({ cashfree_trial_amount: "2.5" }).badgeText, "₹2.50");
});

Deno.test("urls must be https with a host", () => {
  assertEquals(resolveConfig({ app_logo_url: "http://x.com/a.png" }).logoUrl, null);
  assertEquals(resolveConfig({ app_logo_url: "https:///a.png" }).logoUrl, null);
  assertEquals(resolveConfig({ app_logo_url: "nonsense" }).logoUrl, null);
  assertEquals(resolveConfig({ app_logo_url: " https://x.com/a.png " }).logoUrl, "https://x.com/a.png");
  assertEquals(resolveConfig({ webview_url: "https://site.app" }).webUrl, "https://site.app");
});

Deno.test("features: split on |, blanks dropped, at most four", () => {
  assertEquals(resolveConfig({ paywall_features: "a| |b|c|d|e" }).features, ["a", "b", "c", "d"]);
  assertEquals(resolveConfig({ paywall_features: "" }).features, []);
});

Deno.test("feature icons keep blank slots so pairing holds", () => {
  const c = resolveConfig({ paywall_feature_icons: "bolt||crown" });
  assertEquals(c.featureIcons, ["bolt", "", "crown"]);
});

Deno.test("login slides pair by position before dropping bad images", () => {
  const c = resolveConfig({
    login_slide_images: "https://a.com/1.png|http://bad|https://a.com/3.png",
    login_slide_titles: "One|Two",
  });
  assertEquals(c.loginSlides, [
    { imageUrl: "https://a.com/1.png", title: "One" },
    { imageUrl: "https://a.com/3.png", title: "" },
  ]);
});

Deno.test("amounts must be positive finite numbers", () => {
  assertEquals(resolveConfig({ cashfree_trial_amount: "0" }).trialAmount, 3);
  assertEquals(resolveConfig({ cashfree_trial_amount: "-5" }).trialAmount, 3);
  assertEquals(resolveConfig({ cashfree_trial_amount: "abc" }).trialAmount, 3);
  assertEquals(resolveConfig({ cashfree_trial_amount: "0x10" }).trialAmount, 3);
  assertEquals(resolveConfig({ cashfree_recurring_amount: "149" }).recurringPriceLabel, "₹149");
});

Deno.test("video shape accepts w:h, w/h and decimals, clamped to 1:4..4:1", () => {
  assertEquals(resolveConfig({ paywall_video_aspect_ratio: "9:16" }).videoAspectRatio, 0.5625);
  assertEquals(resolveConfig({ paywall_video_aspect_ratio: "16/9" }).videoAspectRatio, 16 / 9);
  assertEquals(resolveConfig({ paywall_video_aspect_ratio: "0.75" }).videoAspectRatio, 0.75);
  assertEquals(resolveConfig({ paywall_video_aspect_ratio: "1:10" }).videoAspectRatio, 1);
  assertEquals(resolveConfig({ paywall_video_aspect_ratio: "9:0" }).videoAspectRatio, 1);
});

Deno.test("strike price flag reads yes/no words and keeps default otherwise", () => {
  assertEquals(resolveConfig({ paywall_show_strike_price: "NO" }).showStrikePrice, false);
  assertEquals(resolveConfig({ paywall_show_strike_price: "1" }).showStrikePrice, true);
  assertEquals(resolveConfig({ paywall_show_strike_price: "maybe" }).showStrikePrice, false);
});

Deno.test("autopay text fills both price placeholders", () => {
  const c = resolveConfig({
    paywall_autopay_text: "{trial} now, {recurring}/mo, {recurring} again",
    cashfree_recurring_amount: "199",
  });
  assertEquals(c.autoPayStatement, "₹3 now, ₹199/mo, ₹199 again");
});

Deno.test("social proofs: list, blank hides", () => {
  assertEquals(resolveConfig({ paywall_social_proofs: "x | y" }).socialProofs, ["x", "y"]);
  assertEquals(resolveConfig({}).socialProofs, []);
});

Deno.test("mergeRows: null/undefined inherit, any string overrides", () => {
  const merged = mergeRows({ app_name: "Evos", theme_color: "#111111" }, {
    app_name: "Facebook",
    theme_color: null,
    paywall_subtitle: undefined,
  });
  assertEquals(merged, {
    app_name: "Facebook",
    theme_color: "#111111",
    login_slide_images: "",
    login_slide_titles: "",
  });
});

Deno.test("mergeRows: a source shows only its own login slides, never the global ones", () => {
  const global = { login_slide_images: "https://a.com/g.png", login_slide_titles: "Global" };
  const none = mergeRows(global, { login_slide_images: null, login_slide_titles: null });
  assertEquals(resolveConfig(none).loginSlides, []);
  const own = mergeRows(global, { login_slide_images: "https://a.com/p.png", login_slide_titles: "Partner" });
  assertEquals(own.login_slide_images, "https://a.com/p.png");
  assertEquals(own.login_slide_titles, "Partner");
});

Deno.test("parseColor accepts RRGGBB with or without #", () => {
  assertEquals(parseColor("#ab12CD"), "#AB12CD");
  assertEquals(parseColor("ab12cd"), "#AB12CD");
  assertEquals(parseColor("#abc"), null);
  assertEquals(parseColor(null), null);
});

Deno.test("formatRupees: whole numbers bare, others two decimals", () => {
  assertEquals(formatRupees(3), "₹3");
  assertEquals(formatRupees(2.5), "₹2.50");
  assertEquals(formatRupees(1299), "₹1299");
});

Deno.test("previewCardSize fits the ratio inside the box", () => {
  assertEquals(previewCardSize(312, 342, 1), { width: 312, height: 312 });
  assertEquals(previewCardSize(312, 342, 0.5625), { width: 342 * 0.5625, height: 342 });
  assertEquals(previewCardSize(312, 342, 16 / 9), { width: 312, height: 312 / (16 / 9) });
});

Deno.test("starIcons rounds to full/half/empty like the paywall", () => {
  assertEquals(starIcons("4.6"), ["star", "star", "star", "star", "star_half"]);
  assertEquals(starIcons("4.8"), ["star", "star", "star", "star", "star"]);
  assertEquals(starIcons("x"), Array(5).fill("star_outline"));
  assertEquals(starIcons("9"), Array(5).fill("star"));
});

Deno.test("iconFor: https image, known name (any case), else the fallback", () => {
  assertEquals(iconFor("https://x.com/i.png", "check"), { url: "https://x.com/i.png" });
  assertEquals(iconFor("Crown", "check"), { symbol: "workspace_premium" });
  assertEquals(iconFor("", "check"), { symbol: "check" });
  assertEquals(iconFor("nope", "auto_awesome"), { symbol: "auto_awesome" });
});

Deno.test("iconFor: inherited object names are not icons", () => {
  assertEquals(iconFor("constructor", "check"), { symbol: "check" });
  assertEquals(iconFor("__proto__", "check"), { symbol: "check" });
  assertEquals(iconFor("toString", "check"), { symbol: "check" });
});
