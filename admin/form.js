// The editor form: which fields exist, how they are drawn, and how they are
// read back. Each field names the screen and the part of it that it changes
// (`screen`, `part`), which the preview uses to jump there and point at it.
//
// A field left BLANK means "use the app's default"; typing a value overrides
// it for this source. (On the wire, blank -> null.)

import { iconGlyph, PAYWALL_ICONS } from "./preview/resolve.js";

// Everyday fields, always shown.
const BASIC = [
  { key: "app_name", label: "App name", type: "text", screen: "signin", part: "name", help: "Shown on the sign-in, paywall and web page screens." },
  { key: "app_logo_url", label: "Logo image", type: "image", screen: "signin", part: "logo", help: "Link to a square image (https). Blank shows the first letter of the name." },
  { key: "theme_color", label: "Brand colour", type: "color", screen: "paywall", part: "primary", help: "Every screen's colours are built from this one." },
  { key: "webview_url", label: "Website link", type: "url", screen: "web", part: "web", help: "The page a subscriber opens after paying (https)." },
  { key: "cashfree_trial_amount", label: "Trial price (today)", type: "price", screen: "paywall", part: "price", help: "Taken today, for the first 24 hours." },
  { key: "cashfree_recurring_amount", label: "Monthly price", type: "price", screen: "paywall", part: "price", help: "Charged every month after the trial." },
  { key: "paywall_subtitle", label: "Short tagline", type: "text", screen: "paywall", part: "subtitle", help: "One line under the paywall heading. Optional." },
  { key: "paywall_cta_text", label: "Button text", type: "text", screen: "paywall", part: "cta", help: 'The main button, e.g. "Try Now".' },
];

// Advanced, under an expander. `sub` = a subheading; `special` = a custom block.
const ADVANCED = [
  { sub: "Branding" },
  { key: "paywall_accent_color", label: "Highlight colour", type: "color", screen: "paywall", part: "accent", help: "The price pill, the big price and the icons. Blank uses the brand colour." },
  { sub: "Paywall heading" },
  { key: "paywall_title_prefix", label: "Heading — first part", type: "text", screen: "paywall", part: "heading", help: 'e.g. "1-Day".' },
  { key: "paywall_title_badge", label: "Heading — pill", type: "text", screen: "paywall", part: "heading", help: "Blank shows the trial price." },
  { key: "paywall_title_suffix", label: "Heading — last part", type: "text", screen: "paywall", part: "heading", help: 'e.g. "Trial".' },
  { sub: "Trust & social proof" },
  { key: "paywall_rating_value", label: "Rating", type: "text", screen: "paywall", part: "rating", help: "e.g. 4.6. Blank hides the rating." },
  { key: "paywall_rating_caption", label: "Rating caption", type: "text", screen: "paywall", part: "rating", help: "Text beside the rating." },
  { key: "paywall_social_proofs", label: "Social proof lines", type: "text", screen: "paywall", part: "social", help: "Short lines that rotate every 3 seconds under the price. Separate several with a | ." },
  { key: "paywall_social_proof_icon", label: "Social proof icon", type: "icon", fallback: "auto_awesome", screen: "paywall", part: "social", help: "Pick an icon or paste an image link. Default is a sparkle." },
  { sub: "Features (the icons row on the paywall)" },
  { special: "features" },
  { sub: "Preview media" },
  { key: "paywall_preview_image_url", label: "Preview image", type: "image", screen: "paywall", part: "media", help: "Image on the paywall (https). Also the video's poster." },
  { key: "paywall_video_url", label: "Preview video", type: "url", screen: "paywall", part: "media", help: "Video on the paywall (https). Plays instead of the image." },
  { key: "paywall_video_aspect_ratio", label: "Video shape", type: "text", screen: "paywall", part: "media", help: "e.g. 9:16 (portrait) or 16:9 (landscape)." },
  { sub: "Options" },
  { key: "paywall_show_strike_price", label: "Strike through the monthly price", type: "bool3", screen: "paywall", part: "price", help: "Show the monthly price crossed out next to the trial price." },
  { sub: "Payment wording" },
  { key: "paywall_autopay_text", label: "Auto-pay sentence", type: "longtext", screen: "paywall", part: "autopay", help: "Use {trial} and {recurring} where the prices should appear." },
  { key: "paywall_upi_select_text", label: "UPI chooser label", type: "text", screen: "paywall", part: "upi-select", help: "Shown in the bottom bar only when the phone has no UPI app." },
  { key: "paywall_upi_sheet_title", label: "UPI sheet title", type: "text", screen: "upi", part: "sheet-title", help: "Title of the sheet listing the UPI apps." },
  { sub: "Plan" },
  { key: "plan_name", label: "Plan name", type: "text", screen: null, help: "Internal name of the plan. Not shown on any screen." },
  { key: "cashfree_plan_id", label: "Cashfree plan id", type: "text", screen: null, help: "Blank builds the plan from the prices above. Not shown on any screen." },
  { sub: "Login slideshow" },
  { special: "slides" },
];

const MAX_FEATURES = 4;
const DEFAULT_SEED = "#6D28D9";

// Every single-value field (for reading the form back). Features and slides
// are handled on their own below.
const SINGLE_FIELDS = [...BASIC, ...ADVANCED.filter((f) => f.key)];

const isHex = (v) => /^#?[0-9a-fA-F]{6}$/.test(v.trim());
const hashed = (v) => (v && !v.startsWith("#") ? `#${v}` : v);

export function el(tag, attrs = {}, ...kids) {
  const n = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === "class") n.className = v;
    else if (k === "html") n.innerHTML = v;
    else n.setAttribute(k, v);
  }
  for (const kid of kids) n.append(kid);
  return n;
}

// The wrapper carries what the preview needs to find this field's part.
function fieldWrap(key, label, meta) {
  const wrap = el("div", {
    class: "field", "data-key": key, "data-label": label,
    "data-screen": meta.screen ?? "", "data-part": meta.part ?? "", "data-help": meta.help ?? "",
  });
  // A group (features, slides) or the icon picker has no single input to
  // label, so its title is plain text, not a <label for>.
  const title = meta.plainLabel
    ? el("span", { class: "label" }, label)
    : el("label", { for: `f_${key}` }, label);
  const head = el("div", { class: "label-row" }, title, el("span", { class: "tag" }, "Default"));
  wrap.append(head);
  return wrap;
}

// ---- Icon picker -------------------------------------------------------------
// One listener for every picker: a click outside a picker closes its popover.
document.addEventListener("click", (e) => {
  document.querySelectorAll(".ip").forEach((ip) => {
    if (!ip.contains(e.target)) ip.querySelector(".ip-pop").hidden = true;
  });
});

// Value: "" (the app's default glyph), an icon name from PAYWALL_ICONS, or an
// https image link. Writes to a hidden input and fires `input` like any field.
function iconPicker(value, fallback, inputAttrs) {
  const hidden = el("input", { type: "hidden", ...inputAttrs });
  hidden.value = value;
  const face = el("button", { type: "button", class: "ip-face", "aria-haspopup": "true", "aria-label": "Choose icon" });
  const pop = el("div", { class: "ip-pop", hidden: "" });
  const wrap = el("div", { class: "ip" }, face, hidden, pop);

  const drawFace = () => {
    const v = hidden.value.trim();
    face.innerHTML = /^https:\/\//i.test(v)
      ? `<img src="${v.replace(/"/g, "&quot;")}" alt="">`
      : `<span class="ms">${iconGlyph(v) ?? fallback}</span>`;
    face.classList.toggle("is-default", v === "");
    face.title = v || "Default";
  };
  const choose = (v) => {
    hidden.value = v;
    drawFace();
    pop.hidden = true;
    hidden.dispatchEvent(new Event("input", { bubbles: true }));
    face.focus();
  };

  const grid = el("div", { class: "ip-grid" });
  const def = el("button", { type: "button", class: "ip-opt", title: "Default" },
    el("span", { class: "ms" }, fallback), el("small", {}, "default"));
  def.onclick = () => choose("");
  grid.append(def);
  for (const [name, glyph] of Object.entries(PAYWALL_ICONS)) {
    const opt = el("button", { type: "button", class: "ip-opt", title: name },
      el("span", { class: "ms" }, glyph), el("small", {}, name.replace("_", " ")));
    opt.onclick = () => choose(name);
    grid.append(opt);
  }
  const url = el("input", { type: "url", class: "ip-url", placeholder: "…or paste an image link (https)" });
  url.value = /^https:\/\//i.test(value) ? value : "";
  url.onkeydown = (e) => { if (e.key === "Enter") { e.preventDefault(); choose(url.value.trim()); } };
  url.oninput = (e) => e.stopPropagation(); // only a chosen value counts
  const useUrl = el("button", { type: "button", class: "addrow" }, "Use link");
  useUrl.onclick = () => choose(url.value.trim());
  pop.append(grid, el("div", { class: "ip-urlrow" }, url, useUrl));

  face.onclick = () => { pop.hidden = !pop.hidden; };
  wrap.addEventListener("keydown", (e) => { if (e.key === "Escape") { pop.hidden = true; face.focus(); } });
  drawFace();
  return wrap;
}

// ---- Single fields ---------------------------------------------------------
function fieldNode(f, row, defaultFor, onChange) {
  const current = row && row[f.key] != null ? String(row[f.key]) : "";
  const wrap = fieldWrap(f.key, f.label, { ...f, plainLabel: f.type === "icon" });
  const placeholder = defaultFor(f.key) ? `Default: ${defaultFor(f.key)}` : "Leave blank for the app default";

  let control;
  if (f.type === "price") {
    const input = el("input", { type: "number", id: `f_${f.key}`, min: "0", step: "0.01", placeholder: `Default: ₹${defaultFor(f.key)}` });
    input.value = current;
    control = el("div", { class: "money" }, el("span", { class: "rupee" }, "₹"), input);
  } else if (f.type === "color") {
    const fallbackHex = () => hashed(defaultFor(f.key)) || DEFAULT_SEED;
    const text = el("input", { type: "text", id: `f_${f.key}`, placeholder: `Default: ${defaultFor(f.key) || "brand colour"}` });
    text.value = current;
    const swatch = el("input", { type: "color", id: `c_${f.key}`, "aria-label": `${f.label} picker` });
    swatch.value = isHex(current) ? hashed(current) : fallbackHex();
    swatch.oninput = () => { text.value = swatch.value; };
    text.oninput = () => { if (isHex(text.value)) swatch.value = hashed(text.value); };
    const reset = el("button", { type: "button", class: "reset" }, "Default");
    reset.onclick = () => { text.value = ""; swatch.value = fallbackHex(); onChange(); };
    control = el("div", { class: "colour" }, swatch, text, reset);
  } else if (f.type === "image") {
    const input = el("input", { type: "url", id: `f_${f.key}`, placeholder: "Paste an image link (https)" });
    input.value = current;
    const thumb = el("img", { class: "thumb", alt: "" });
    if (current) thumb.src = current;
    thumb.onerror = () => thumb.removeAttribute("src");
    input.addEventListener("input", () => {
      if (input.value.trim()) thumb.src = input.value.trim(); else thumb.removeAttribute("src");
    });
    control = el("div", { class: "imgfield" }, input, thumb);
  } else if (f.type === "icon") {
    control = iconPicker(current, f.fallback, { id: `f_${f.key}` });
  } else if (f.type === "bool3") {
    const sel = el("select", { id: `f_${f.key}` });
    for (const [v, t] of [["", "Use default"], ["true", "Yes"], ["false", "No"]]) sel.append(el("option", { value: v }, t));
    sel.value = row && row[f.key] === true ? "true" : row && row[f.key] === false ? "false" : "";
    control = sel;
  } else if (f.type === "longtext") {
    control = el("textarea", { id: `f_${f.key}`, placeholder });
    control.value = current;
  } else {
    control = el("input", { type: f.type === "url" ? "url" : "text", id: `f_${f.key}`, placeholder });
    control.value = current;
  }
  wrap.append(control);
  if (f.help) wrap.append(el("div", { class: "help" }, f.help));
  return wrap;
}

// Features: up to 4 rows of [icon][text] -> paywall_features + _feature_icons.
// Pairing follows the app: icon i belongs to the i-th non-blank feature.
function featuresNode(row, defaultFor) {
  const wrap = fieldWrap("paywall_features", "Features (up to 4)", {
    screen: "paywall", part: "features", help: "Each feature is a round icon with a short label under it.", plainLabel: true,
  });
  const split = (v) => (v == null ? [] : String(v).split("|").map((s) => s.trim()));
  const feats = split(row?.paywall_features).filter(Boolean);
  const icons = split(row?.paywall_feature_icons);
  const defaults = String(defaultFor("paywall_features") || "Full access|Cancel anytime|Secure UPI AutoPay")
    .split("|").map((s) => s.trim()).filter(Boolean);
  for (let i = 0; i < MAX_FEATURES; i++) {
    const text = el("input", {
      type: "text", class: "feat", "aria-label": `Feature ${i + 1}`,
      placeholder: defaults[i] ? `Default: ${defaults[i]}` : "Leave blank to skip",
    });
    text.value = feats[i] ?? "";
    wrap.append(el("div", { class: "row2" }, iconPicker(icons[i] ?? "", "check", { class: "feat-icon" }), text));
  }
  wrap.append(el("div", { class: "help" }, "Click an icon to change it (default is a tick). Fill the labels to replace the default features; blank rows are skipped."));
  return wrap;
}

// Login slideshow: image + caption rows -> login_slide_images / _titles.
function slidesNode(row, onChange) {
  const wrap = fieldWrap("login_slide_images", "Login slideshow", {
    screen: "signin", part: "carousel", plainLabel: true,
    help: "Screens shown above the sign-in form, moving every 2 seconds. Needs at least one https image. Left empty, this source shows no slideshow (the global slides are never used for a source).",
  });
  const box = el("div", { id: "slides" });
  const imgs = row?.login_slide_images ? String(row.login_slide_images).split("|") : [];
  const caps = row?.login_slide_titles ? String(row.login_slide_titles).split("|") : [];
  const addRow = (img = "", cap = "") => {
    const i = el("input", { type: "url", class: "slide-img", placeholder: "Image link (https)", "aria-label": "Slide image" });
    i.value = img;
    const c = el("input", { type: "text", class: "slide-cap", placeholder: "Title (optional)", "aria-label": "Slide title" });
    c.value = cap;
    const rm = el("button", { type: "button", class: "rm", "aria-label": "Remove slide" }, "✕");
    const r = el("div", { class: "row2" }, i, c, rm);
    rm.onclick = () => { r.remove(); onChange(); };
    box.append(r);
  };
  imgs.forEach((img, idx) => addRow(img.trim(), (caps[idx] || "").trim()));
  wrap.append(box);
  const add = el("button", { type: "button", class: "addrow" }, "+ Add slide");
  add.onclick = () => { addRow(); box.lastElementChild.querySelector("input").focus(); };
  wrap.append(add, el("div", { class: "help" }, "Leave empty for none: the sign-in screen then shows the logo and form only."));
  return wrap;
}

/** Fills `form` with the editor for `row` (null for a new source). */
export function buildForm(form, row, defaultFor, onChange) {
  form.innerHTML = "";

  const head = el("div", { class: "card" });
  head.append(el("h2", {}, row ? `Editing “${row.source}”` : "New source"));
  head.append(el("p", { class: "intro" }, "Fill only what should differ for this source. Anything left blank uses the normal app setting. Click a field to see where it appears on the phone."));
  const skWrap = el("div", { class: "field" });
  skWrap.append(el("label", { for: "f_source" }, "Source tag"));
  const sk = el("input", { type: "text", id: "f_source", placeholder: "e.g. filmyface" });
  sk.value = row ? row.source : "";
  if (row) sk.disabled = true;
  skWrap.append(sk, el("div", { class: "help" }, "The utm_source from your install link. Lowercase, no spaces."));
  const actWrap = el("div", { class: "field" });
  actWrap.append(el("label", { for: "f_is_active" }, "Status"));
  const act = el("select", { id: "f_is_active" });
  act.append(el("option", { value: "true" }, "Active — used by the app"), el("option", { value: "false" }, "Hidden — ignored by the app"));
  act.value = row ? String(!!row.is_active) : "true";
  actWrap.append(act);
  head.append(el("div", { class: "grid" }, skWrap, actWrap));
  form.append(head);

  const basics = el("div", { class: "card" });
  basics.append(el("h2", {}, "Basics"));
  const bgrid = el("div", { class: "grid" });
  for (const f of BASIC) bgrid.append(fieldNode(f, row, defaultFor, onChange));
  basics.append(bgrid);
  form.append(basics);

  const adv = el("details", { class: "adv" });
  adv.append(el("summary", {}, "Show advanced options"));
  const body = el("div", { class: "advbody" });
  let grid = null;
  const flushGrid = () => { if (grid) { body.append(grid); grid = null; } };
  for (const item of ADVANCED) {
    if (item.sub) { flushGrid(); body.append(el("div", { class: "subhead" }, item.sub)); continue; }
    if (item.special === "features") { flushGrid(); body.append(featuresNode(row, defaultFor)); continue; }
    if (item.special === "slides") { flushGrid(); body.append(slidesNode(row, onChange)); continue; }
    if (!grid) grid = el("div", { class: "grid" });
    grid.append(fieldNode(item, row, defaultFor, onChange));
  }
  flushGrid();
  adv.append(body);
  form.append(adv);
  // A source that already changes advanced fields opens with them showing.
  adv.open = !!row && SINGLE_FIELDS.some((f) => !BASIC.includes(f) && row[f.key] != null);
}

// ---- Read the form back ----------------------------------------------------
const valOf = (form, key) => {
  const v = (form.querySelector(`#f_${key}`)?.value ?? "").trim();
  return v === "" ? null : v;
};

/** The upsert payload: every allowlisted column, blank -> null. */
export function collect(form) {
  const payload = {
    source: form.querySelector("#f_source").value.trim().toLowerCase(),
    is_active: form.querySelector("#f_is_active").value === "true",
  };
  for (const f of SINGLE_FIELDS) payload[f.key] = valOf(form, f.key);

  // Icons pair with the kept (non-blank) features. With every label blank the
  // default features are kept, and the icons pair with those in row order.
  const rows = [...form.querySelectorAll(".feat")].map((input) => ({
    text: input.value.trim(),
    icon: input.parentElement.querySelector(".feat-icon").value.trim(),
  }));
  const kept = rows.some((r) => r.text) ? rows.filter((r) => r.text) : rows;
  const icons = kept.map((r) => r.icon);
  while (icons.length && !icons[icons.length - 1]) icons.pop();
  const feats = kept.map((r) => r.text).filter(Boolean);
  payload.paywall_features = feats.length ? feats.join("|") : null;
  payload.paywall_feature_icons = icons.length ? icons.join("|") : null;

  // Slides: only rows with an image.
  const imgs = [], caps = [];
  form.querySelectorAll("#slides .row2").forEach((r) => {
    const img = r.querySelector(".slide-img").value.trim();
    if (!img) return;
    imgs.push(img);
    caps.push(r.querySelector(".slide-cap").value.trim());
  });
  payload.login_slide_images = imgs.length ? imgs.join("|") : null;
  payload.login_slide_titles = imgs.length ? caps.join("|") : null;
  return payload;
}

/** Marks each field Custom (overrides the app) or Default (inherits). */
export function refreshTags(form, payload) {
  form.querySelectorAll(".field[data-key]").forEach((wrap) => {
    const key = wrap.dataset.key;
    const custom = key === "paywall_features"
      ? payload.paywall_features != null || payload.paywall_feature_icons != null
      : payload[key] != null;
    const tag = wrap.querySelector(".tag");
    tag.textContent = custom ? "Custom" : "Default";
    tag.classList.toggle("custom", custom);
  });
}
