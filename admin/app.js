// Admin panel logic. Everything goes through the admin-source-config edge
// function; the browser holds only the public anon key and the admin password
// the operator typed (sessionStorage, this tab only).
//
// The form is in form.js; the live phone preview is in preview/.

import { buildForm, collect, el, refreshTags } from "./form.js";
import { createPreview } from "./preview/preview.js";
import { loadColorLibrary } from "./preview/theme.js";
import { mergeRows } from "./preview/resolve.js";

const cfg = globalThis.ADMIN_CONFIG;
const FN_URL = `${cfg.supabaseUrl}/functions/v1/admin-source-config`;
const REST_URL = `${cfg.supabaseUrl}/rest/v1`;
const SECRET_KEY = "evos_admin_secret";
const BLUR_DELAY_MS = 120;
const $ = (id) => document.getElementById(id);

// Placeholders when app_config doesn't return a key (the app's own defaults).
const HARD_DEFAULTS = {
  app_name: "Evos", theme_color: "#6D28D9",
  cashfree_trial_amount: "3", cashfree_recurring_amount: "299",
  paywall_title_prefix: "1-Day", paywall_title_suffix: "Trial",
  paywall_cta_text: "Try Now",
};
let globalDefaults = {}; // the public app_config rows, as the app reads them
const defaultFor = (key) => (globalDefaults[key] || HARD_DEFAULTS[key] || "");

// ---- Backend ---------------------------------------------------------------
const secret = () => sessionStorage.getItem(SECRET_KEY) || "";

function showMsg(text, kind) {
  const box = $("msg");
  box.textContent = text;
  box.className = `msg ${kind}`;
  if (kind === "ok") setTimeout(() => (box.className = "msg"), 2500);
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
  } catch (error) {
    // Placeholders and the preview fall back to the app's built-in defaults.
    console.warn("Could not read app_config; using the app's built-in defaults.", error);
  }
}

// ---- Views -----------------------------------------------------------------
function showLogin() {
  preview?.stop();
  $("form").innerHTML = ""; // nothing from the last source stays in the page
  $("login").classList.remove("hidden");
  $("listView").classList.add("hidden");
  $("editView").classList.add("hidden");
  $("logout").classList.add("hidden");
  document.body.classList.remove("editing");
}

async function showList() {
  preview?.stop();
  $("login").classList.add("hidden");
  $("editView").classList.add("hidden");
  $("listView").classList.remove("hidden");
  $("logout").classList.remove("hidden");
  document.body.classList.remove("editing", "preview-open");
  const data = await call("list");
  const box = $("sources");
  box.innerHTML = "";
  if (!data.sources.length) {
    box.append(el("p", { class: "intro" }, "No sources yet. Click “+ New source”."));
    return;
  }
  for (const row of data.sources) {
    const dot = el("span", { class: "dot" });
    dot.style.background = row.theme_color ? `#${String(row.theme_color).replace("#", "")}` : defaultFor("theme_color");
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

// ---- Editor + live preview -------------------------------------------------
let editingSource = null;
let preview = null;
let blurTimer = 0;

// What the phone shows: the app's global settings with this form on top.
function previewRows() {
  const { source: _source, is_active: _active, ...overrides } = collect($("form"));
  return mergeRows(globalDefaults, overrides);
}

function onFormChange() {
  refreshTags($("form"), collect($("form")));
  preview.update(previewRows());
}

function fieldMeta(target) {
  const wrap = target.closest?.(".field[data-key]");
  if (!wrap) return null;
  return {
    screen: wrap.dataset.screen || null,
    part: wrap.dataset.part || null,
    label: wrap.dataset.label,
    hint: wrap.dataset.help,
  };
}

function showEditor(row) {
  editingSource = row ? row.source : null;
  $("listView").classList.add("hidden");
  $("editView").classList.remove("hidden");
  document.body.classList.add("editing");
  const form = $("form");
  buildForm(form, row, defaultFor, onFormChange);
  $("delete").classList.toggle("hidden", !row);

  preview ??= createPreview($("preview"));
  onFormChange();
  globalThis.scrollTo({ top: 0 });
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
$("secret").onkeydown = (e) => { if (e.key === "Enter") $("unlock").click(); };

$("logout").onclick = () => { sessionStorage.removeItem(SECRET_KEY); $("secret").value = ""; showLogin(); };
$("new").onclick = () => showEditor(null);
$("cancel").onclick = () => showList().catch((e) => showMsg(e.message, "err"));

$("save").onclick = async () => {
  const payload = collect($("form"));
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

// The form element lives for the whole page, so these are wired once.
$("form").addEventListener("submit", (e) => e.preventDefault()); // Enter must not reload
$("form").addEventListener("input", onFormChange);
$("form").addEventListener("change", onFormChange);
// Moving between fields fires focusout then focusin: wait a moment so the
// preview does not flash back to "nothing focused" in between.
$("form").addEventListener("focusin", (e) => {
  clearTimeout(blurTimer);
  const meta = fieldMeta(e.target);
  if (meta) preview?.focusField(meta); else preview?.blurField();
});
$("form").addEventListener("focusout", () => {
  clearTimeout(blurTimer);
  blurTimer = setTimeout(() => preview?.blurField(), BLUR_DELAY_MS);
});

$("saveTop").classList.remove("hidden"); // shown only while editing, by CSS
$("saveTop").onclick = () => $("save").click();

// Small screens: the preview opens over the form.
$("previewFab").onclick = () => document.body.classList.add("preview-open");
$("previewClose").onclick = () => document.body.classList.remove("preview-open");

// The colour library loads in the background; the preview repaints with the
// exact colours once it arrives.
loadColorLibrary().then(() => { if (preview) onFormChange(); });

// Resume a tab that already unlocked.
if (secret()) {
  loadDefaults().then(showList).catch(() => showLogin());
} else {
  showLogin();
}
