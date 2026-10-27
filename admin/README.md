# Evos source admin panel

A tiny standalone web panel for the `webview_sources` table: the per-install-source
app identity (name, logo, colour, every paywall field, the login carousel and the
web page URL). This is **Phase A — visual identity only**. Prices and the plan
(`cashfree_*_amount`, `cashfree_plan_id`, `plan_name`) are global for now and are
**Phase B**.

## How it is wired

```
browser (admin/)  ──POST──►  admin-source-config edge function  ──service role──►  webview_sources
   anon key + x-admin-secret
```

- The browser holds only the **anon key** (public, same as the app) and the admin
  **secret** the operator types (kept in this tab's `sessionStorage`, nowhere else).
- All reads and writes go through the `admin-source-config` edge function, which runs
  with the **service role**. The table has **no anon/authenticated write policy** — the
  function is the only writer, matching the project's security rules.
- The function only ever writes the allowlisted columns in
  `supabase/functions/_shared/source_config.ts`. `webview_sources` has no secret columns,
  so the panel can never touch the Cashfree/SMS secrets.

## Setup (one time)

1. **Push the migration and deploy the function** (owner's explicit step — nothing here is
   auto-deployed):
   ```sh
   supabase db push
   supabase functions deploy admin-source-config
   ```
2. **Set the admin secret.** In the Supabase Table Editor open `app_config` and set
   `admin_panel_secret` to a strong random value. A **blank** secret makes the function
   refuse every request, so the panel stays locked until you set it.

## Running the panel

It is plain static files — no build step.

```sh
cd admin && python3 -m http.server 8787   # then open http://localhost:8787
```

Or host the folder on any static host (Netlify, Hostinger, GitHub Pages). To point it at
another project, edit the two public values in `admin/config.js`.

Open it, enter the admin secret, and add/edit sources.

## How the form works (simplified UI)

- **Fill only what should differ for this source. Leave a field blank to use the normal app
  default** — the greyed placeholder shows what that default is (read live from `app_config`).
  On save, a blank field is sent as `NULL` (inherit); a filled field overrides for this source.
- **Basics** (name, logo, brand colour, website link, trial/monthly price, tagline, button)
  are always shown; everything else is under **Show advanced options**.
- A **live preview** on the right updates as you type (brand colour, name/logo, prices, button).
- **Source tag** is the lowercased `utm_source` from the install link (fixed once created).
- **Status: Hidden** makes the row invisible to the app (RLS), a safe way to disable a source
  without deleting it.

The simplified UI intentionally drops the old per-field "override / inherit" checkbox and the
rare "set empty to hide a section" trick; blank always means "use the app default". The backend
allowlist/validation in `source_config.ts` is unchanged, so anything advanced can still be set
directly in the Supabase Table Editor if ever needed.
