// HTML for the six onboarding screens, drawn from the Flutter widgets in
// lib/screens/onboarding/ at their real sizes (1 CSS px = 1 dp on a 360x800
// phone). Every number here comes from that code: change a padding in the app
// and change it here. `data-part` names what a field controls, so the panel
// can point at it while that field is being edited.

import { iconFor, previewCardSize, starIcons } from "./resolve.js";

export const SCREEN_W = 360;
export const SCREEN_H = 800;

export const SCREENS = [
  { id: "signin", label: "Sign-in" },
  { id: "otp", label: "Code" },
  { id: "paywall", label: "Paywall" },
  { id: "upi", label: "UPI apps" },
  { id: "processing", label: "Processing" },
  { id: "web", label: "Web page" },
];

// What a phone with a UPI app shows: the first installed app is preselected.
const UPI_APPS = ["PhonePe", "Google Pay", "Paytm"];
const SAMPLE_NUMBER = "+91 98765 43210";

const esc = (s) =>
  String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

// Material Symbols Rounded, filled like Flutter's Icons.*_rounded.
const ms = (name, size, cls = "") =>
  `<span class="ms ${cls}" style="font-size:${size}px" aria-hidden="true">${name}</span>`;

const gap = (h) => `<div style="height:${h}px;flex:none"></div>`;

function firstLetter(name) {
  if (globalThis.Intl?.Segmenter) {
    const [first] = new Intl.Segmenter().segment(name);
    return first ? first.segment.toUpperCase() : "";
  }
  return [...name][0]?.toUpperCase() ?? "";
}

// The ghost marks where a part would be while its field is blank and focused.
const ghost = (st, part, label) =>
  st.ghost === part ? `<div class="ghost" data-part="${part}">${esc(label)}</div>` : "";

/** An icon from the paywall's list, an https image, or the fallback glyph. */
function paywallIcon(value, fallback, size, cls) {
  const icon = iconFor(value, fallback);
  if (icon.url) {
    // The fallback glyph sits hidden behind the image and shows if it breaks.
    return `<img class="ic-img" src="${esc(icon.url)}" alt="" style="width:${size}px;height:${size}px"
      data-err="bad">${ms(fallback, size, `${cls} ic-fallback`)}`;
  }
  return ms(icon.symbol, size, cls);
}

// ---- Shared chrome ---------------------------------------------------------

const statusBar = () => `
  <div class="sb">
    <span class="sb-time">9:41</span>
    <span class="sb-icons">${ms("signal_cellular_alt", 15)}${ms("wifi", 15)}${ms("battery_full", 15)}</span>
  </div>`;

const navBar = () => `<div class="gb"><span></span></div>`;

/** BrandLogo: the logo, or the name's first letter on a primary tile. */
function brandLogo(cfg, size) {
  const img = cfg.logoUrl
    ? `<img src="${esc(cfg.logoUrl)}" alt="" data-err="remove">`
    : "";
  return `
    <span class="logo" data-part="logo primary" style="width:${size}px;height:${size}px;border-radius:${size * 0.28}px">
      <span class="logo-letter" style="font-size:${size * 0.46}px">${esc(firstLetter(cfg.appName))}</span>${img}
    </span>`;
}

/** BrandHeader: 32px logo, 10px gap, the name in titleMedium w700. */
const brandHeader = (cfg) => `
  <div class="bh">${brandLogo(cfg, 32)}<span class="bh-name tm w7" data-part="name">${esc(cfg.appName)}</span></div>`;

const screen = (body, cls = "") => `<div class="scr ${cls}">${statusBar()}${body}${navBar()}</div>`;

// ---- Sign-in (phone_screen.dart) -------------------------------------------

function phoneField(focused) {
  return `
    <div class="pfield ${focused ? "focused" : ""}">
      <span class="pfx">
        <span class="pfx-ink"><span class="flag">🇮🇳</span><span class="digits">+91</span>${ms("expand_more", 20, "osv")}</span>
        <span class="pfx-div"></span>
      </span>
      <span class="digits hint">98765 43210</span>
    </div>`;
}

function phoneForm(cfg, withCarousel) {
  return `
    <div class="t-welcome ${withCarousel ? "hs" : "hm"} w7" data-part="name">Welcome to ${esc(cfg.appName)}</div>
    ${gap(6)}
    <div class="bl osv">Enter your mobile number to sign in or create your account.</div>
    ${gap(20)}
    ${phoneField(!withCarousel)}
    ${gap(16)}
    <div class="btn filled disabled" style="height:56px;border-radius:16px"><span class="tm w7">Send code</span></div>
    ${gap(10)}
    <div class="bsm osv center">We'll send a 6-digit code by SMS.</div>`;
}

function carousel(cfg, st) {
  const slides = cfg.loginSlides;
  const index = st.slideIndex % slides.length;
  const pages = slides.map((s) => `
    <div class="car-page"><div class="shot">
      <img src="${esc(s.imageUrl)}" alt="" data-err="broken">
      <div class="shot-ph">${ms("smartphone", 36)}</div>
    </div></div>`).join("");
  const dots = slides.length > 1
    ? slides.map((_, i) => `<span class="dot ${i === index ? "on" : ""}"></span>`).join("")
    : "";
  return `
    <div class="car" data-part="carousel" data-count="${slides.length}">
      <div class="car-title-box"><div class="car-title tl w7">${esc(slides[index].title)}</div></div>
      <div class="car-pages"><div class="car-track" style="transform:translateX(-${index * 100}%)">${pages}</div></div>
      <div class="car-dots">${dots}</div>
    </div>`;
}

function signIn(cfg, st) {
  if (cfg.loginSlides.length) {
    return screen(`
      <div class="safe" style="padding:12px 20px 8px">
        ${brandHeader(cfg)}
        ${gap(16)}
        ${carousel(cfg, st)}
        ${gap(24)}
        <div class="col">${phoneForm(cfg, true)}</div>
      </div>`);
  }
  return screen(`
    <div class="safe" style="padding:12px 20px 8px">
      <div class="scroll" style="padding-top:20px">
        ${brandLogo(cfg, 56)}
        ${ghost(st, "carousel", "Slideshow — add an image to switch to this layout")}
        ${gap(28)}
        ${phoneForm(cfg, false)}
      </div>
    </div>`);
}

// ---- Code entry (otp_screen.dart) ------------------------------------------

const appBar = (leading, title, actions = "") => `
  <div class="appbar">${leading}${title}<span class="spacer"></span>${actions}</div>`;

const iconButton = (name) => `<span class="ibtn">${ms(name, 24)}</span>`;

function otp() {
  const boxes = Array.from({ length: 6 }, (_, i) => `<span class="otp-box ${i === 0 ? "focused" : ""}"></span>`).join("");
  return screen(`
    ${appBar(iconButton("arrow_back"), "")}
    <div class="safe" style="padding:0 24px 16px">
      <div class="scroll">
        <div class="hm w7">Enter the code</div>
        ${gap(8)}
        <div class="bl osv">Sent by SMS to ${SAMPLE_NUMBER}</div>
        ${gap(28)}
        <div class="otp-row">${boxes}</div>
        ${gap(12)}
        <div class="bm osv tab" style="padding:14px 0">Resend code in 0:30</div>
      </div>
      ${gap(16)}
      <div class="btn filled disabled stadium" style="height:54px"><span class="ll">Verify</span></div>
    </div>`);
}

// ---- Paywall (paywall_screen.dart) -----------------------------------------

function heading(cfg) {
  const prefix = cfg.paywallTitlePrefix ? `<span class="hs w7">${esc(cfg.paywallTitlePrefix)}</span>` : "";
  const suffix = cfg.paywallTitleSuffix ? `<span class="hs w7">${esc(cfg.paywallTitleSuffix)}</span>` : "";
  return `
    <div class="pw-heading" data-part="heading">
      ${prefix}<span class="pill-badge tm w7" data-part="accent price">${esc(cfg.badgeText)}</span>${suffix}
    </div>`;
}

function rating(cfg, st) {
  if (!cfg.ratingValue) return ghost(st, "rating", "★★★★★ Rating appears here");
  const stars = starIcons(cfg.ratingValue).map((s) => ms(s === "star_outline" ? "star" : s, 18, s === "star_outline" ? "o gold" : "gold")).join("");
  const caption = cfg.ratingCaption ? `<span class="bm osv">${esc(cfg.ratingCaption)}</span>` : "";
  return `${gap(12)}<div class="pw-rating" data-part="rating"><span class="stars">${stars}</span><span class="bl w7">${esc(cfg.ratingValue)}</span>${caption}</div>`;
}

function media(cfg, st) {
  if (cfg.previewVideoUrl) {
    const size = previewCardSize(SCREEN_W - 48, SCREEN_H * 0.45, cfg.videoAspectRatio);
    const poster = cfg.previewImageUrl ? `<img class="poster" src="${esc(cfg.previewImageUrl)}" alt="">` : "";
    return `${gap(22)}
      <div class="media vid" data-part="media" data-video="${esc(cfg.previewVideoUrl)}" data-fallback="${cfg.previewImageUrl ? 1 : 0}"
           style="width:${size.width}px;height:${size.height}px">
        ${poster}<span class="spin"></span>
        <span class="paused">${ms("play_arrow", 32)}</span>
      </div>`;
  }
  if (cfg.previewImageUrl) {
    return `${gap(22)}<div class="media" data-part="media" style="height:180px"><img class="cover" src="${esc(cfg.previewImageUrl)}" alt="" data-err="remove"></div>`;
  }
  return st.ghost === "media" ? `${gap(22)}${ghost(st, "media", "Preview video or image appears here")}` : "";
}

function features(cfg) {
  if (!cfg.features.length) return "";
  const cols = cfg.features.map((label, i) => `
    <div class="pw-feat">
      <span class="feat-circle" data-part="accent">${paywallIcon(cfg.featureIcons[i] ?? "", "check", 20, "")}</span>
      ${gap(8)}
      <span class="lm">${esc(label)}</span>
    </div>`).join("");
  return `${gap(26)}<div class="feats" data-part="features">${cols}</div>`;
}

function price(cfg) {
  const strike = cfg.showStrikePrice ? `<span class="tl osv strike">${esc(cfg.recurringPriceLabel)}</span><span style="width:14px"></span>` : "";
  return `<div class="pw-price" data-part="price">${strike}<span class="dm w7 accent" data-part="accent">${esc(cfg.trialPriceLabel)}</span></div>`;
}

function socialProof(cfg, st) {
  if (!cfg.socialProofs.length) return st.ghost === "social" ? `${gap(20)}${ghost(st, "social", "Social proof strip appears here")}` : "";
  const line = cfg.socialProofs[st.socialIndex % cfg.socialProofs.length];
  return `${gap(20)}
    <div class="social" data-part="social" data-count="${cfg.socialProofs.length}">
      <span data-part="accent" class="social-icon">${paywallIcon(cfg.socialProofIcon, "auto_awesome", 18, "accent")}</span>
      <span class="bsm social-text">${esc(line)}</span>
    </div>`;
}

function paywallBody(cfg, st) {
  const subtitle = cfg.paywallSubtitle
    ? `${gap(10)}<div class="bl osv center" data-part="subtitle">${esc(cfg.paywallSubtitle)}</div>`
    : st.ghost === "subtitle" ? `${gap(10)}${ghost(st, "subtitle", "Tagline appears here")}` : "";
  const upiLabel = st.noUpiApp ? cfg.upiSelectText : UPI_APPS[0];
  return `
    <div class="pw-head">${brandHeader(cfg)}</div>
    <div class="scroll pw-scroll" data-scroll="paywall">
      ${heading(cfg)}
      ${subtitle}
      ${rating(cfg, st)}
      ${media(cfg, st)}
      ${features(cfg)}
      ${gap(28)}
      ${price(cfg)}
      ${gap(12)}
      <div class="bsm osv center" data-part="autopay">${esc(cfg.autoPayStatement)}</div>
      ${socialProof(cfg, st)}
    </div>
    <div class="pw-bar">
      <span class="upi-pick" data-part="upi-select"><span class="tm w7 ellipsis">${esc(upiLabel)}</span>${ms("keyboard_arrow_down", 24)}</span>
      <span class="btn filled stadium cta" data-part="cta primary"><span class="tm w7 ellipsis">${esc(cfg.ctaText)}</span></span>
    </div>`;
}

const paywall = (cfg, st) => screen(`<div class="safe pw">${paywallBody(cfg, st)}</div>`);

function upiSheet(cfg, st) {
  const tiles = UPI_APPS.map((name, i) => `
    <div class="tile">
      <span class="avatar tm">${esc(name[0])}</span>
      <span class="bl tile-title">${esc(name)}</span>
      ${i === 0 ? ms("check", 24, "primary") : ""}
    </div>`).join("");
  return screen(`
    <div class="safe pw">${paywallBody(cfg, st)}</div>
    <div class="scrim"></div>
    <div class="sheet">
      <div class="handle"><span></span></div>
      <div class="tl w7" style="padding:0 16px 8px" data-part="sheet-title">${esc(cfg.upiSheetTitle)}</div>
      ${tiles}
      ${gap(16)}
    </div>`, "has-sheet");
}

// ---- Processing (_Processing in paywall_screen.dart) -----------------------

function processing(cfg) {
  return screen(`
    <div class="safe proc">
      <div class="proc-ring">
        <svg viewBox="0 0 104 104" class="ring"><circle cx="52" cy="52" r="50"></circle></svg>
        ${brandLogo(cfg, 56)}
      </div>
      ${gap(28)}
      <div class="tl w7 center">Opening ${esc(UPI_APPS[0])}</div>
      ${gap(10)}
      <div class="bl osv center">This takes a few seconds. Please keep the app open.</div>
    </div>`);
}

// ---- Web page (web_screen.dart) --------------------------------------------

// Full screen, no app bar (no logo, Reload or Log out), as in the app since
// 2026-10-31.
function web(cfg) {
  if (!cfg.webUrl) {
    return screen(`
      <div class="safe" style="padding:12px 24px 16px" data-part="web">
        <div class="scroll nopage">
          <span class="np-circle">${ms("hourglass_top", 64)}</span>
          ${gap(28)}
          <div class="hs w7 center">You're all set</div>
          ${gap(10)}
          <div class="bl osv center">Your access is active. The page is not available yet; check again in a little while.</div>
        </div>
        <div class="btn tonal stadium" style="height:54px"><span class="ll">Check again</span></div>
      </div>`);
  }
  let host = cfg.webUrl;
  try { host = new URL(cfg.webUrl).host; } catch { /* keep the raw link */ }
  // The live site is laid over this slot by preview.js on the big phone only.
  return screen(`
    <div class="web-slot" data-part="web" data-url="${esc(cfg.webUrl)}">
      <div class="web-card">${ms("language", 40, "osv")}<div class="tm w7">${esc(host)}</div><div class="bm osv">Opens full-screen after payment</div></div>
    </div>`);
}

const RENDERERS = { signin: signIn, otp, paywall, upi: upiSheet, processing, web };

/**
 * @param {string} id one of SCREENS
 * @param {object} cfg from resolveConfig()
 * @param {{slideIndex:number, socialIndex:number, ghost:string|null, noUpiApp:boolean}} st
 */
export function renderScreen(id, cfg, st) {
  return RENDERERS[id](cfg, st);
}
