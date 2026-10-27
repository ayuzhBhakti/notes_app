// Admin panel backend. The standalone web panel (see /admin) calls this to
// read and write the webview_sources table. It runs with the service role, so
// it is the ONLY way those rows are written: the table itself has no anon or
// authenticated write policy, matching the project's security rules.
//
// Auth is a shared secret, not a Supabase user: the x-admin-secret header must
// equal the private app_config row `admin_panel_secret`. A blank stored secret
// refuses every request, so an un-provisioned project is never open.
//
// It only ever writes the allowlisted columns in _shared/source_config.ts, and
// webview_sources has no secret columns, so this cannot touch Cashfree/SMS
// secrets however it is called.

import { createServiceClient } from "../_shared/app_config.ts";
import { buildSourceRow, normalizeSource } from "../_shared/source_config.ts";

const FN = "admin-source-config";

// The panel is a static site on another origin, so browsers send a preflight.
// No credentials are used (the secret is a custom header, not a cookie), so a
// wildcard origin is safe here.
const CORS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "content-type, x-admin-secret",
  "Access-Control-Max-Age": "86400",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

/** Length-independent compare, so a wrong secret leaks no timing signal. */
function secretMatches(given: string, expected: string): boolean {
  if (expected.length === 0) return false;
  const a = new TextEncoder().encode(given);
  const b = new TextEncoder().encode(expected);
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const service = createServiceClient();

    // Verify the admin secret against the private app_config row.
    const given = req.headers.get("x-admin-secret") ?? "";
    const { data: secretRow } = await service
      .from("app_config")
      .select("value")
      .eq("key", "admin_panel_secret")
      .maybeSingle<{ value: string }>();
    const expected = (secretRow?.value ?? "").trim();
    if (!secretMatches(given, expected)) {
      console.warn(JSON.stringify({ fn: FN, step: "unauthorized" }));
      return json({ error: "Unauthorized" }, 401);
    }

    const body = await req.json().catch(() => null);
    if (!body || typeof body !== "object") {
      return json({ error: "Invalid JSON body" }, 400);
    }
    const action = (body as Record<string, unknown>).action;

    switch (action) {
      case "list": {
        const { data, error } = await service
          .from("webview_sources")
          .select()
          .order("source");
        if (error) return json({ error: error.message }, 500);
        return json({ sources: data ?? [] });
      }

      case "upsert": {
        const built = buildSourceRow(body as Record<string, unknown>);
        if ("error" in built) return json({ error: built.error }, 400);
        const { data, error } = await service
          .from("webview_sources")
          .upsert(built.row, { onConflict: "source" })
          .select()
          .maybeSingle();
        if (error) return json({ error: error.message }, 500);
        console.log(JSON.stringify({ fn: FN, step: "upsert", source: built.row.source }));
        return json({ source: data });
      }

      case "delete": {
        const source = normalizeSource((body as Record<string, unknown>).source);
        if (!source) return json({ error: "invalid or missing source" }, 400);
        const { error } = await service
          .from("webview_sources")
          .delete()
          .eq("source", source);
        if (error) return json({ error: error.message }, 500);
        console.log(JSON.stringify({ fn: FN, step: "delete", source }));
        return json({ deleted: source });
      }

      default:
        return json({ error: `unknown action: ${String(action)}` }, 400);
    }
  } catch (error) {
    console.error(JSON.stringify({ fn: FN, step: "failed", error: String(error) }));
    return json({ error: "Server error" }, 500);
  }
});
