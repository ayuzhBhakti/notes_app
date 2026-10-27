// The per-source identity columns the admin panel may write, and how each is
// validated. This list is the write allowlist: a request can only set columns
// named here, so the admin panel can never put a value into a column that is
// not a per-source setting. Secrets are not columns of webview_sources at all,
// so they cannot appear here; do not add one.
//
// Column names are the matching app_config keys verbatim (the app overlays
// them by name). Phase A is visual identity only. Prices/plan
// (cashfree_*_amount, cashfree_plan_id, plan_name) are Phase B and are added
// here together with the create-cashfree-subscription change, never before.

export type ColumnKind =
  | "text"
  | "url"
  | "urlList"
  | "color"
  | "ratio"
  | "bool"
  | "amount";

export interface SourceColumn {
  key: string;
  kind: ColumnKind;
}

export const SOURCE_COLUMNS: readonly SourceColumn[] = [
  { key: "webview_url", kind: "url" },
  { key: "app_name", kind: "text" },
  { key: "app_logo_url", kind: "url" },
  { key: "theme_color", kind: "color" },
  { key: "paywall_accent_color", kind: "color" },
  { key: "paywall_title_prefix", kind: "text" },
  { key: "paywall_title_badge", kind: "text" },
  { key: "paywall_title_suffix", kind: "text" },
  { key: "paywall_subtitle", kind: "text" },
  { key: "paywall_rating_value", kind: "text" },
  { key: "paywall_rating_caption", kind: "text" },
  { key: "paywall_preview_image_url", kind: "url" },
  { key: "paywall_video_url", kind: "url" },
  { key: "paywall_video_aspect_ratio", kind: "ratio" },
  { key: "paywall_features", kind: "text" },
  { key: "paywall_feature_icons", kind: "text" },
  { key: "paywall_social_proofs", kind: "text" },
  { key: "paywall_social_proof_icon", kind: "text" },
  { key: "paywall_show_strike_price", kind: "bool" },
  { key: "paywall_cta_text", kind: "text" },
  { key: "paywall_autopay_text", kind: "text" },
  { key: "paywall_upi_select_text", kind: "text" },
  { key: "paywall_upi_sheet_title", kind: "text" },
  { key: "login_slide_images", kind: "urlList" },
  { key: "login_slide_titles", kind: "text" },
  // Phase B: plan and prices. Amounts are read server-side when charging.
  { key: "plan_name", kind: "text" },
  { key: "cashfree_plan_id", kind: "text" },
  { key: "cashfree_trial_amount", kind: "amount" },
  { key: "cashfree_recurring_amount", kind: "amount" },
] as const;

const COLUMN_BY_KEY = new Map<string, SourceColumn>(
  SOURCE_COLUMNS.map((c) => [c.key, c]),
);

/** A source key: lowercase utm_source, letters/digits/._- only. */
export function normalizeSource(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const source = raw.trim().toLowerCase();
  if (source.length === 0 || source.length > 64) return null;
  return /^[a-z0-9._-]+$/.test(source) ? source : null;
}

function isHttps(value: string): boolean {
  try {
    return new URL(value).protocol === "https:";
  } catch {
    return false;
  }
}

/**
 * Validates and coerces one column value coming from the admin panel.
 * Returns the value to store (string, boolean, or null to inherit the global
 * value), or an error string naming the problem. An empty string is a valid,
 * deliberate override (it hides that part of the screen), distinct from null.
 */
export function coerceColumn(
  key: string,
  raw: unknown,
): { value: string | boolean | null } | { error: string } {
  const column = COLUMN_BY_KEY.get(key);
  if (!column) return { error: `unknown column: ${key}` };

  // null / undefined mean "inherit the global app_config value".
  if (raw === null || raw === undefined) return { value: null };

  if (column.kind === "bool") {
    if (typeof raw === "boolean") return { value: raw };
    const text = String(raw).trim().toLowerCase();
    if (text === "") return { value: null };
    if (["true", "yes", "1"].includes(text)) return { value: true };
    if (["false", "no", "0"].includes(text)) return { value: false };
    return { error: `${key} must be a boolean` };
  }

  if (typeof raw !== "string") return { error: `${key} must be a string` };
  const value = raw.trim();
  if (value === "") {
    // An amount is inherit-or-set: a blank one means "inherit the global
    // price" (null), never a stored "". A stored "" would read as the global
    // price server-side but as the app's built-in default on the paywall, so
    // the display and the charge could disagree. Every other field keeps ""
    // as a deliberate "hide this part".
    return { value: column.kind === "amount" ? null : "" };
  }

  switch (column.kind) {
    case "url":
      if (!isHttps(value)) return { error: `${key} must be an https URL` };
      return { value };
    case "urlList": {
      const parts = value.split("|").map((p) => p.trim()).filter((p) => p);
      for (const part of parts) {
        if (!isHttps(part)) return { error: `${key} has a non-https URL` };
      }
      return { value: parts.join("|") };
    }
    case "color":
      if (!/^#?[0-9a-fA-F]{6}$/.test(value)) {
        return { error: `${key} must be a #RRGGBB colour` };
      }
      return { value: value.startsWith("#") ? value : `#${value}` };
    case "ratio":
      if (!/^\d+(\.\d+)?([:/]\d+(\.\d+)?)?$/.test(value)) {
        return { error: `${key} must be like 9:16 or 0.5625` };
      }
      return { value };
    case "amount": {
      // Stored as text to match the app_config rows, but it must be a real,
      // positive amount: this is money a customer will be charged.
      const amount = Number(value);
      if (!Number.isFinite(amount) || amount <= 0) {
        return { error: `${key} must be a positive amount` };
      }
      return { value };
    }
    case "text":
      return { value };
  }
}

/**
 * Builds the row to upsert from the admin panel's payload: the source key,
 * is_active, and only the allowlisted columns, each validated. Columns absent
 * from the payload are set to null so clearing a field in the panel inherits
 * the global value again.
 */
export function buildSourceRow(
  payload: Record<string, unknown>,
): { row: Record<string, unknown> } | { error: string } {
  const source = normalizeSource(payload.source);
  if (!source) return { error: "invalid or missing source" };

  const row: Record<string, unknown> = { source };
  row.is_active = payload.is_active === undefined
    ? true
    : payload.is_active === true || payload.is_active === "true";

  for (const column of SOURCE_COLUMNS) {
    const result = coerceColumn(column.key, payload[column.key]);
    if ("error" in result) return { error: result.error };
    row[column.key] = result.value;
  }
  return { row };
}
