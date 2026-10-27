// Admin panel logic. Everything goes through the admin-source-config edge
// function; the browser holds only the public anon key and the admin password
// the operator typed (sessionStorage, this tab only).
//
// Model for the form: a field left BLANK means "use the app's default"; typing
// a value overrides it for this source. (On the wire, blank -> null.)

"use strict";

const cfg = globalThis.ADMIN_CONFIG;
const FN_URL = `${cfg.supabaseUrl}/functions/v1/admin-source-config`;
const REST_URL = `${cfg.supabaseUrl}/rest/v1`;
const SECRET_KEY = "evos_admin_secret";
const $ = (id) => document.getElementById(id);

// ---- Field schema ----------------------------------------------------------
// Everyday fields, always shown.
const BASIC = [
  { key: "app_name", label: "App name", type: "text", help: "Shown on the sign-in and paywall screens." },
  { key: "app_logo_url", label: "Logo image", type: "image", help: "Link to a square image (https). Blank shows the first letter of the name." },
  { key: "theme_color", label: "Brand colour", type: "color", help: "The main colour used across the app." },
  { key: "webview_url", label: "Website link", type: "url", help: "The page a subscriber opens after paying (https)." },
  { key: "cashfree_trial_amount", label: "Trial price (today)", type: "price", help: "Taken today, for the first 24 hours." },
  { key: "cashfree_recurring_amount", label: "Monthly price", type: "price", help: "Charged every month after the trial." },
  { key: "paywall_subtitle", label: "Short tagline", type: "text", help: "One line under the paywall heading. Optional." },
  { key: "paywall_cta_text", label: "Button text", type: "text", help: 'The main button, e.g. "Try Now".' },
];

// Advanced, under an expander. `sub` = a subheading; `special` = a custom block.
const ADVANCED = [
  { sub: "Branding" },
  { key: "paywall_accent_color", label: "Highlight colour", type: "color", help: "Used for the price and icons. Blank uses the brand colour." },
  { sub: "Paywall heading" },
  { key: "paywall_title_prefix", label: "Heading — first part", type: "text", help: 'e.g. "1-Day".' },
  { key: "paywall_title_badge", label: "Heading — pill", type: "text", help: "Blank shows the trial price." },
  { key: "paywall_title_suffix", label: "Heading — last part", type: "text", help: 'e.g. "Trial".' },
  { sub: "Trust & social proof" },
  { key: "paywall_rating_value", label: "Rating", type: "text", help: "e.g. 4.6. Blank hides the rating." },
  { key: "paywall_rating_caption", label: "Rating caption", type: "text", help: "Text beside the rating." },
  { key: "paywall_social_proofs", label: "Social proof lines", type: "text", help: "Short lines that rotate under the price. Separate several with a | ." },
  { key: "paywall_social_proof_icon", label: "Social proof icon", type: "text", help: "Icon name or image link." },
  { sub: "Features (shown as ticks on the paywall)" },
  { special: "features" },
  { key: "paywall_feature_icons", label: "Feature icons", type: "text", help: "Optional, one per feature, separated by a | ." },
  { sub: "Preview media" },
  { key: "paywall_preview_image_url", label: "Preview image", type: "image", help: "Image on the paywall (https)." },
  { key: "paywall_video_url", label: "Preview video", type: "url", help: "Video on the paywall (https). Plays instead of the image." },
  { key: "paywall_video_aspect_ratio", label: "Video shape", type: "text", help: "e.g. 9:16 (portrait) or 16:9 (landscape)." },
  { sub: "Options" },
  { key: "paywall_show_strike_price", label: "Strike through the monthly price", type: "bool3", help: "Show the monthly price crossed out next to the trial price." },
  { sub: "Payment wording" },
  { key: "paywall_autopay_text", label: "Auto-pay sentence", type: "longtext", help: "Use {trial} and {recurring} where the prices should appear." },
  { key: "paywall_upi_select_text", label: "UPI chooser label", type: "text", help: "Label above the UPI app list." },
  { key: "paywall_upi_sheet_title", label: "UPI sheet title", type: "text", help: "Title of the payment sheet." },
  { sub: "Plan" },
  { key: "plan_name", label: "Plan name", type: "text", help: "Internal name of the plan." },
  { key: "cashfree_plan_id", label: "Cashfree plan id", type: "text", help: "Blank builds the plan from the prices above." },
  { sub: "Login slideshow" },
  { special: "slides" },
];

// Every single-value field (for reading the form back). Features and slides
// are handled on their own below.
const SINGLE_FIELDS = [...BASIC, ...ADVANCED.filter((f) => f.key)];

// Fallbacks when app_config doesn't return a key (match the app's own defaults).
const HARD_DEFAULTS = {
  app_name: "Evos", theme_color: "#6D28D9", paywall_accent_color: "#6D28D9",
  cashfree_trial_amount: "3", cashfree_recurring_amount: "299",
  paywall_title_prefix: "1-Day", paywall_title_suffix: "Trial",
  paywall_cta_text: "Try Now",
};
let globalDefaults = {}; // filled from app_config (public rows)
const defaultFor = (key) => (globalDefaults[key] || HARD_DEFAULTS[key] || "");

// ---- Backend ---------------------------------------------------------------
const secret = () => sessionStorage.getItem(SECRET_KEY) || "";

function showMsg(text, kind) {
  const el = $("msg");
  el.textContent = text;
  el.className = `msg ${kind}`;
  if (kind === "ok") setTimeout(() => (el.className = "msg"), 2500);
  globalThis.scrollTo({ top: 0, behavior: "smooth" });
}

async function call(action, extra = {}) {
  const res = await fetch(FN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-admin-secret": secret() },
    body: JSON.stringify({ action, ...extra }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || `Request failed (${res.status})`);
  return data;
}

async function loadDefaults() {
  try {
    const res = await fetch(`${REST_URL}/app_config?select=key,value`, {
      headers: { apikey: cfg.anonKey, Authorization: `Bearer ${cfg.anonKey}` },
    });
    const rows = await res.json();
    if (Array.isArray(rows)) {
      globalDefaults = Object.fromEntries(rows.map((r) => [r.key, r.value ?? ""]));
    }
  } catch (_) { /* placeholders fall back to HARD_DEFAULTS */ }
}

// ---- Helpers ---------------------------------------------------------------
const isHex = (v) => /^#?[0-9a-fA-F]{6}$/.test(v.trim());
const hashed = (v) => (v && !v.startsWith("#") ? `#${v}` : v);

function el(tag, attrs = {}, ...kids) {
  const n = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === "class") n.className = v;
    else if (k === "html") n.innerHTML = v;
    else n.setAttribute(k, v);
  }
  for (const kid of kids) n.append(kid);
  return n;
}

// ---- Views -----------------------------------------------------------------
function showLogin() {
  $("login").classList.remove("hidden");
  $("listView").classList.add("hidden");
  $("editView").classList.add("hidden");
  $("logout").classList.add("hidden");
}

async function showList() {
  $("login").classList.add("hidden");
  $("editView").classList.add("hidden");
  $("listView").classList.remove("hidden");
  $("logout").classList.remove("hidden");
  const data = await call("list");
  const box = $("sources");
  box.innerHTML = "";
  if (!data.sources.length) {
    box.append(el("p", { class: "intro" }, "No sources yet. Click “+ New source”."));
    return;
  }
  for (const row of data.sources) {
    const dot = el("span", { class: "dot" });
    dot.style.background = hashed(row.theme_color) || defaultFor("theme_color");
    const item = el("div", { class: "source-item" },
      dot,
      el("span", { class: "name" }, row.app_name || "(default name)"),
      el("span", { class: "src" }, row.source),
      el("span", { class: "spacer" }),
      el("span", { class: `pill ${row.is_active ? "on" : "off"}` }, row.is_active ? "active" : "hidden"),
    );
    const edit = el("button", {}, "Edit");
    edit.onclick = () => showEditor(row);
    item.append(edit);
    box.append(item);
  }
}

// Build one single-value field. `row` is the loaded source (or null for new).
function fieldNode(f, row) {
  const current = row && row[f.key] != null ? String(row[f.key]) : "";
  const wrap = el("div", { class: "field" });
  wrap.append(el("label", { for: `f_${f.key}` }, f.label));

  let control;
  if (f.type === "price") {
    const input = el("input", { type: "number", id: `f_${f.key}`, min: "0", step: "0.01", placeholder: `Default: ₹${defaultFor(f.key)}` });
    input.value = current;
    control = el("div", { class: "money" }, el("span", { class: "rupee" }, "₹"), input);
  } else if (f.type === "color") {
    const text = el("input", { type: "text", id: `f_${f.key}`, placeholder: `Default: ${defaultFor(f.key)}` });
    text.value = current;
    const swatch = el("input", { type: "color", id: `c_${f.key}` });
    swatch.value = isHex(current) ? hashed(current) : hashed(defaultFor(f.key)) || "#6D28D9";
    swatch.oninput = () => { text.value = swatch.value; renderPreview(); };
    text.oninput = () => { if (isHex(text.value)) swatch.value = hashed(text.value); renderPreview(); };
    const reset = el("button", { type: "button", class: "reset" }, "Default");
    reset.onclick = () => { text.value = ""; swatch.value = hashed(defaultFor(f.key)) || "#6D28D9"; renderPreview(); };
    control = el("div", { class: "colour" }, swatch, text, reset);
  } else if (f.type === "image") {
    const input = el("input", { type: "url", id: `f_${f.key}`, placeholder: "Paste an image link (https)" });
    input.value = current;
    const thumb = el("img", { class: "thumb", id: `p_${f.key}`, alt: "" });
    if (current) thumb.src = current;
    thumb.onerror = () => { thumb.removeAttribute("src"); };
    input.oninput = () => { if (input.value.trim()) thumb.src = input.value.trim(); else thumb.removeAttribute("src"); renderPreview(); };
    control = el("div", { class: "imgfield" }, input, thumb);
  } else if (f.type === "bool3") {
    const sel = el("select", { id: `f_${f.key}` });
    for (const [v, t] of [["", "Use default"], ["true", "Yes"], ["false", "No"]]) {
      sel.append(el("option", { value: v }, t));
    }
    sel.value = row && row[f.key] === true ? "true" : row && row[f.key] === false ? "false" : "";
    control = sel;
  } else if (f.type === "longtext") {
    const ta = el("textarea", { id: `f_${f.key}`, placeholder: defaultFor(f.key) ? `Default: ${defaultFor(f.key)}` : "Leave blank for the app default" });
    ta.value = current;
    control = ta;
  } else {
    const input = el("input", { type: f.type === "url" ? "url" : "text", id: `f_${f.key}`, placeholder: defaultFor(f.key) ? `Default: ${defaultFor(f.key)}` : "Leave blank for the app default" });
    input.value = current;
    control = input;
  }
  wrap.append(control);
  if (f.help) wrap.append(el("div", { class: "help" }, f.help));
  return wrap;
}

// Features: up to 4 simple rows -> paywall_features (joined with |).
function featuresNode(row) {
  const wrap = el("div", { class: "field rows" });
  wrap.append(el("label", {}, "Features (up to 4)"));
  const existing = (row && row.paywall_features ? String(row.paywall_features).split("|") : [])
    .map((s) => s.trim());
  for (let i = 0; i < 4; i++) {
    const input = el("input", { type: "text", class: "feat", placeholder: i === 0 ? "e.g. Full access" : "Leave blank to skip" });
    input.value = existing[i] || "";
    wrap.append(el("div", { class: "row2" }, input));
  }
  wrap.append(el("div", { class: "help" }, "Shown as a ticked list on the paywall. Blank rows are skipped."));
  return wrap;
}

// Login slideshow: image + caption rows -> login_slide_images / _titles.
function slidesNode(row) {
  const wrap = el("div", { class: "field rows" });
  wrap.append(el("label", {}, "Login slideshow"));
  const box = el("div", { id: "slides" });
  const imgs = row && row.login_slide_images ? String(row.login_slide_images).split("|") : [];
  const caps = row && row.login_slide_titles ? String(row.login_slide_titles).split("|") : [];
  const addRow = (img = "", cap = "") => {
    const i = el("input", { type: "url", class: "slide-img", placeholder: "Image link (https)" });
    i.value = img;
    i.oninput = renderPreview;
    const c = el("input", { type: "text", class: "slide-cap", placeholder: "Caption (optional)" });
    c.value = cap;
    const rm = el("button", { type: "button", class: "rm" }, "✕");
    const r = el("div", { class: "row2" }, i, c, rm);
    rm.onclick = () => r.remove();
    box.append(r);
  };
  imgs.forEach((img, idx) => addRow(img.trim(), (caps[idx] || "").trim()));
  wrap.append(box);
  const add = el("button", { type: "button", class: "addrow" }, "+ Add slide");
  add.onclick = () => addRow();
  wrap.append(add);
  wrap.append(el("div", { class: "help" }, "Images shown behind the sign-in screen. Leave empty for none." ));
  return wrap;
}

let editingSource = null;

function showEditor(row) {
  editingSource = row ? row.source : null;
  $("listView").classList.add("hidden");
  $("editView").classList.remove("hidden");
  const form = $("form");
  form.innerHTML = "";

  // Source + active.
  const head = el("div", { class: "card" });
  head.append(el("h2", {}, row ? `Editing “${row.source}”` : "New source"));
  head.append(el("p", { class: "intro" }, "Fill only what should differ for this source. Anything left blank uses the normal app setting."));
  const skWrap = el("div", { class: "field" });
  skWrap.append(el("label", { for: "f_source" }, "Source tag"));
  const sk = el("input", { type: "text", id: "f_source", placeholder: "e.g. filmyface" });
  sk.value = row ? row.source : "";
  if (row) sk.disabled = true;
  skWrap.append(sk, el("div", { class: "help" }, "The utm_source from your install link. Lowercase, no spaces."));
  head.append(skWrap);
  const actWrap = el("div", { class: "field" });
  actWrap.append(el("label", { for: "f_is_active" }, "Status"));
  const act = el("select", { id: "f_is_active" });
  act.append(el("option", { value: "true" }, "Active — used by the app"), el("option", { value: "false" }, "Hidden — ignored by the app"));
  act.value = row ? String(!!row.is_active) : "true";
  actWrap.append(act);
  head.append(actWrap);
  form.append(head);

  // Basics.
  const basics = el("div", { class: "card" });
  basics.append(el("h2", {}, "Basics"));
  const bgrid = el("div", { class: "grid" });
  for (const f of BASIC) bgrid.append(fieldNode(f, row));
  basics.append(bgrid);
  form.append(basics);

  // Advanced (collapsed).
  const adv = el("details", { class: "adv" });
  adv.append(el("summary", {}, "Show advanced options"));
  const body = el("div", { class: "advbody" });
  let grid = null;
  const flushGrid = () => { if (grid) { body.append(grid); grid = null; } };
  for (const item of ADVANCED) {
    if (item.sub) { flushGrid(); body.append(el("div", { class: "subhead" }, item.sub)); continue; }
    if (item.special === "features") { flushGrid(); body.append(featuresNode(row)); continue; }
    if (item.special === "slides") { flushGrid(); body.append(slidesNode(row)); continue; }
    if (!grid) grid = el("div", { class: "grid" });
    grid.append(fieldNode(item, row));
  }
  flushGrid();
  adv.append(body);
  form.append(adv);

  $("delete").classList.toggle("hidden", !row);
  form.oninput = renderPreview;
  renderPreview();
}

// ---- Read the form back ----------------------------------------------------
function valOf(f) {
  const v = ($(`f_${f.key}`)?.value ?? "").trim();
  if (f.type === "bool3") return v === "" ? null : v; // "" = default
  return v === "" ? null : v;
}

function collect() {
  const payload = {
    source: $("f_source").value.trim().toLowerCase(),
    is_active: $("f_is_active").value === "true",
  };
  for (const f of SINGLE_FIELDS) payload[f.key] = valOf(f);

  // Features -> paywall_features
  const feats = [...document.querySelectorAll(".feat")].map((i) => i.value.trim()).filter(Boolean);
  payload.paywall_features = feats.length ? feats.join("|") : null;

  // Slides -> login_slide_images / _titles (only rows with an image)
  const imgs = [], caps = [];
  document.querySelectorAll("#slides .row2").forEach((r) => {
    const img = r.querySelector(".slide-img").value.trim();
    if (!img) return;
    imgs.push(img);
    caps.push(r.querySelector(".slide-cap").value.trim());
  });
  payload.login_slide_images = imgs.length ? imgs.join("|") : null;
  payload.login_slide_titles = imgs.length ? caps.join("|") : null;
  return payload;
}

// ---- Live preview ----------------------------------------------------------
function pv(key) {
  const v = ($(`f_${key}`)?.value ?? "").trim();
  return v || defaultFor(key);
}
function renderPreview() {
  const brand = isHex(pv("theme_color")) ? hashed(pv("theme_color")) : "#6D28D9";
  const accentRaw = ($("f_paywall_accent_color")?.value ?? "").trim();
  const accent = isHex(accentRaw) ? hashed(accentRaw) : brand;
  const name = pv("app_name");
  const logo = ($("f_app_logo_url")?.value ?? "").trim();
  const trial = pv("cashfree_trial_amount");
  const monthly = pv("cashfree_recurring_amount");
  const badge = ($("f_paywall_title_badge")?.value ?? "").trim() || `₹${trial}`;
  const title = `${pv("paywall_title_prefix")} ${badge} ${pv("paywall_title_suffix")}`.trim();
  const sub = ($("f_paywall_subtitle")?.value ?? "").trim();
  const cta = pv("paywall_cta_text");
  const logoInner = logo ? `<img src="${escapeHtml(logo)}" alt="" onerror="this.style.display='none'">` : escapeHtml((name[0] || "E").toUpperCase());

  $("preview").innerHTML = `
    <div class="pv-top" style="background:${brand}">
      <div class="pv-logo">${logoInner}</div>
      <div class="pv-name">${escapeHtml(name)}</div>
    </div>
    <div class="pv-body">
      <div class="pv-title">${escapeHtml(title)}</div>
      <div class="pv-sub">${escapeHtml(sub)}</div>
      <div class="pv-price">Pay <b style="color:${accent}">₹${escapeHtml(trial)}</b> today,<br>then ₹${escapeHtml(monthly)}/month</div>
      <button class="pv-cta" style="background:${accent}">${escapeHtml(cta)}</button>
    </div>`;
}
function escapeHtml(s) {
  return String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
}

// ---- Events ----------------------------------------------------------------
$("unlock").onclick = async () => {
  const value = $("secret").value.trim();
  if (!value) return showMsg("Enter the admin password.", "err");
  sessionStorage.setItem(SECRET_KEY, value);
  try {
    await loadDefaults();
    await showList();
    $("msg").className = "msg";
  } catch (e) {
    sessionStorage.removeItem(SECRET_KEY);
    showMsg(e.message === "Unauthorized" ? "Wrong password." : e.message, "err");
  }
};

$("logout").onclick = () => { sessionStorage.removeItem(SECRET_KEY); $("secret").value = ""; showLogin(); };
$("new").onclick = () => showEditor(null);
$("cancel").onclick = () => showList().catch((e) => showMsg(e.message, "err"));

$("save").onclick = async () => {
  const payload = collect();
  if (!payload.source) return showMsg("Please enter a source tag.", "err");
  try {
    await call("upsert", payload);
    showMsg(`Saved “${payload.source}”.`, "ok");
    await showList();
  } catch (e) { showMsg(e.message, "err"); }
};

$("delete").onclick = async () => {
  if (!editingSource) return;
  if (!confirm(`Delete “${editingSource}”? This cannot be undone.`)) return;
  try {
    await call("delete", { source: editingSource });
    showMsg(`Deleted “${editingSource}”.`, "ok");
    await showList();
  } catch (e) { showMsg(e.message, "err"); }
};

// Resume a tab that already unlocked.
if (secret()) {
  loadDefaults().then(showList).catch(() => showLogin());
} else {
  showLogin();
}
