// The app's settings rules, ported from RemoteConfig.fromRows
// (lib/models/remote_config.dart). The preview draws from what this returns,
// so it must stay rule-for-rule with the Dart: a blank that hides a part in
// the app hides it here, a bad link is dropped here as it is there.
// Pure functions only; tested by resolve.test.js.

export const DEFAULT_SEED = "#6D28D9";
const DEFAULT_FEATURES = ["Full access", "Cancel anytime", "Secure UPI AutoPay"];
const MAX_FEATURES = 4;
const MIN_RATIO = 0.25;
const MAX_RATIO = 4;

export const DEFAULT_AUTOPAY_TEXT =
  "{trial} today for the first 24 hours, then {recurring} every month by " +
  "UPI AutoPay. Cancel any time in your UPI app.";

// Name -> Material Symbols glyph, as kPaywallIcons in paywall_screen.dart.
export const PAYWALL_ICONS = Object.freeze({
  check: "check",
  check_circle: "check_circle",
  verified: "verified",
  lock: "lock",
  shield: "shield",
  security: "security",
  star: "star",
  sparkle: "auto_awesome",
  bolt: "bolt",
  rocket: "rocket_launch",
  bell: "notifications",
  rupee: "currency_rupee",
  wallet: "account_balance_wallet",
  card: "credit_card",
  gift: "card_giftcard",
  offer: "local_offer",
  crown: "workspace_premium",
  diamond: "diamond",
  heart: "favorite",
  thumb_up: "thumb_up",
  people: "groups",
  support: "support_agent",
  clock: "schedule",
  calendar: "calendar_month",
  cancel: "cancel",
  phone: "smartphone",
  cloud: "cloud_done",
  ad_free: "block",
});

// Dart's double.tryParse: plain decimal or exponent, no hex, no blanks.
const NUMBER = /^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$/;
const tryParseDouble = (s) => (NUMBER.test(s) ? Number(s) : null);

export function isHttps(text) {
  // WHATWG URL reads "https:///a.png" as host "a.png"; Dart's Uri sees no
  // host and the app drops it, so require the host to follow "//" directly.
  if (!/^https:\/\/[^/?#\s]/i.test(text)) return false;
  try {
    const uri = new URL(text);
    return uri.protocol === "https:" && uri.hostname !== "";
  } catch {
    return false;
  }
}

/** `#RRGGBB` or `RRGGBB` -> `#RRGGBB` upper-case; null for anything else. */
export function parseColor(source) {
  const hex = String(source ?? "").trim().replace(/^#/, "");
  return /^[0-9a-fA-F]{6}$/.test(hex) ? `#${hex.toUpperCase()}` : null;
}

/** ₹3, ₹299, ₹2.50. No thousands separator, as in the app. */
export function formatRupees(amount) {
  return amount === Math.round(amount) ? `₹${amount.toFixed(0)}` : `₹${amount.toFixed(2)}`;
}

/** Settings a source never inherits: with none of its own, no carousel. */
const SOURCE_ONLY_KEYS = ["login_slide_images", "login_slide_titles"];

/**
 * The global rows with this source's filled fields laid on top. Mirrors
 * SupabaseEvosBackend.mergeSourceRow, including its source-only login slides.
 */
export function mergeRows(globalRows, overrides) {
  const merged = { ...globalRows };
  for (const key of SOURCE_ONLY_KEYS) merged[key] = "";
  for (const [key, value] of Object.entries(overrides)) {
    if (value !== null && value !== undefined) merged[key] = String(value);
  }
  return merged;
}

/** The paywall's video card size: fills the width unless that is too tall. */
export function previewCardSize(maxWidth, maxHeight, ratio) {
  let width = maxWidth;
  let height = width / ratio;
  if (height > maxHeight) {
    height = maxHeight;
    width = height * ratio;
  }
  return { width, height };
}

/** Five glyph names for a rating such as "4.6". */
export function starIcons(value) {
  const parsed = tryParseDouble(String(value ?? "").trim()) ?? 0;
  const stars = Math.min(5, Math.max(0, parsed));
  return [0, 1, 2, 3, 4].map((i) =>
    stars >= i + 0.75 ? "star" : stars >= i + 0.25 ? "star_half" : "star_outline"
  );
}

/** The glyph for an icon name (any case), or null. Own keys only, so a
 *  name like "constructor" is unknown here as it is in the app. */
export function iconGlyph(name) {
  const key = String(name ?? "").trim().toLowerCase();
  return Object.hasOwn(PAYWALL_ICONS, key) ? PAYWALL_ICONS[key] : null;
}

/** An https image, a known icon name (any case), or the fallback glyph. */
export function iconFor(value, fallback) {
  const v = String(value ?? "").trim();
  if (isHttps(v)) return { url: v };
  return { symbol: iconGlyph(v) ?? fallback };
}

/** Settings rows -> what the screens show. Mirrors RemoteConfig.fromRows. */
export function resolveConfig(rows) {
  const has = (key) => Object.prototype.hasOwnProperty.call(rows, key);
  const raw = (key) => String(rows[key] ?? "").trim();

  const text = (key, fallback) => raw(key) || fallback;
  // Unlike text(), blank is a real answer here: it hides that part.
  const optional = (key, fallback) => (has(key) ? raw(key) : fallback);
  const url = (key) => (isHttps(raw(key)) ? raw(key) : null);
  const list = (key, fallback) =>
    has(key) ? String(rows[key]).split("|").map((p) => p.trim()).filter(Boolean) : fallback;
  // Blank slots kept, so a missing icon does not shift later ones.
  const paired = (key) => String(rows[key] ?? "").split("|").map((p) => p.trim());
  const amount = (key, fallback) => {
    const value = tryParseDouble(raw(key));
    return value !== null && value > 0 && Number.isFinite(value) ? value : fallback;
  };
  const ratio = (key, fallback) => {
    const value = raw(key);
    const parts = value.split(/[:/]/);
    let result = null;
    if (parts.length === 2) {
      const w = tryParseDouble(parts[0].trim());
      const h = tryParseDouble(parts[1].trim());
      if (w !== null && h !== null && h > 0) result = w / h;
    } else {
      result = tryParseDouble(value);
    }
    return result !== null && result >= MIN_RATIO && result <= MAX_RATIO ? result : fallback;
  };
  const flag = (key, fallback) => {
    const v = raw(key).toLowerCase();
    if (["true", "yes", "1"].includes(v)) return true;
    if (["false", "no", "0"].includes(v)) return false;
    return fallback;
  };
  // Paired before dropping bad images, or later images get the wrong title.
  const slides = () => {
    const images = String(rows.login_slide_images ?? "").split("|");
    const titles = String(rows.login_slide_titles ?? "").split("|");
    return images.flatMap((image, i) =>
      isHttps(image.trim()) ? [{ imageUrl: image.trim(), title: (titles[i] ?? "").trim() }] : []
    );
  };

  const trialAmount = amount("cashfree_trial_amount", 3);
  const recurringAmount = amount("cashfree_recurring_amount", 299);
  const trialPriceLabel = formatRupees(trialAmount);
  const recurringPriceLabel = formatRupees(recurringAmount);
  const paywallTitleBadge = optional("paywall_title_badge", "");
  const autoPayText = optional("paywall_autopay_text", "");

  return {
    appName: text("app_name", "Evos"),
    logoUrl: url("app_logo_url"),
    seedColor: parseColor(rows.theme_color) ?? DEFAULT_SEED,
    paywallTitlePrefix: optional("paywall_title_prefix", "1-Day"),
    paywallTitleBadge,
    paywallTitleSuffix: optional("paywall_title_suffix", "Trial"),
    badgeText: paywallTitleBadge || trialPriceLabel,
    ratingValue: optional("paywall_rating_value", ""),
    ratingCaption: optional("paywall_rating_caption", ""),
    previewImageUrl: url("paywall_preview_image_url"),
    previewVideoUrl: url("paywall_video_url"),
    videoAspectRatio: ratio("paywall_video_aspect_ratio", 1),
    paywallSubtitle: optional("paywall_subtitle", ""),
    features: list("paywall_features", DEFAULT_FEATURES).slice(0, MAX_FEATURES),
    featureIcons: paired("paywall_feature_icons"),
    showStrikePrice: flag("paywall_show_strike_price", false),
    accentColor: parseColor(rows.paywall_accent_color),
    autoPayText,
    autoPayStatement: (autoPayText || DEFAULT_AUTOPAY_TEXT)
      .replaceAll("{trial}", trialPriceLabel)
      .replaceAll("{recurring}", recurringPriceLabel),
    socialProofs: list("paywall_social_proofs", []),
    socialProofIcon: optional("paywall_social_proof_icon", ""),
    ctaText: text("paywall_cta_text", "Try Now"),
    upiSelectText: text("paywall_upi_select_text", "Select UPI App"),
    upiSheetTitle: text("paywall_upi_sheet_title", "Pay with UPI AutoPay"),
    loginSlides: slides(),
    webUrl: url("webview_url"),
    trialAmount,
    recurringAmount,
    trialPriceLabel,
    recurringPriceLabel,
  };
}
