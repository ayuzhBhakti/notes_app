# Evos source admin panel

A small standalone web panel for the `webview_sources` table: the per-install-source
app identity (name, logo, colour, every paywall field, the login carousel and the
web page URL) and, since Phase B, the per-source plan and prices
(`cashfree_*_amount`, `cashfree_plan_id`, `plan_name`).

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
- The global settings shown as placeholders and used by the preview are the public
  `app_config` rows, read with the anon key exactly as the app reads them.

## Files

| File | What it does |
|------|--------------|
| `index.html` | The page and its styles |
| `config.js` | The two public Supabase values |
| `app.js` | Unlock, source list, save/delete, wiring the form to the preview |
| `form.js` | The fields (with the screen and part each one changes), the icon picker, reading the form back |
| `preview/resolve.js` | The app's settings rules, ported from `RemoteConfig.fromRows` (`lib/models/remote_config.dart`) |
| `preview/theme.js` | The colour scheme, built as `BrandShell` builds it (`ColorScheme.fromSeed`, fidelity) |
| `preview/screens.js` | The six screens as HTML, at the Flutter widgets' own sizes |
| `preview/preview.js` | The phone, the screen rail, "All screens", highlighting, timers, video, web frame |
| `preview/preview.css` | Phone styles: Material 3 type scale, Roboto, Material Symbols Rounded |
| `preview/resolve.test.js` | Tests for the rules: `deno test admin/preview/resolve.test.js` |
| `preview/vendor/` | Google's material-color-utilities 0.3.0 (Apache-2.0), saved locally |

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

It is plain static files with no build step. The scripts are ES modules, so open it
through a web server, not as a `file://` page:

```sh
cd admin && python3 -m http.server 8787   # then open http://localhost:8787
```

Or host the folder on any static host (Netlify, Hostinger, GitHub Pages). To point it at
another project, edit the two public values in `admin/config.js`.

Open it, enter the admin secret, and add/edit sources.

## How the form works

- **Fill only what should differ for this source. Leave a field blank to use the normal app
  default** — the greyed placeholder shows what that default is (read live from `app_config`).
  On save, a blank field is sent as `NULL` (inherit); a filled field overrides for this source.
  Each field has a **Default / Custom** tag saying which it is.
- **Basics** (name, logo, brand colour, website link, trial/monthly price, tagline, button)
  are always shown; everything else is under **Show advanced options** (opened automatically
  for a source that already changes an advanced field).
- **Features** are four rows of *icon + label*. Click the round icon to pick one of the
  app's icon names or paste an https image link. Icon *n* goes with the *n*-th filled label,
  as the app pairs them. With every label blank the default features are kept and the
  icons apply to those.
- **Save** is also in the header while editing, so it is always in reach.
- **Source tag** is the lowercased `utm_source` from the install link (fixed once created).
- **Status: Hidden** makes the row invisible to the app (RLS), a safe way to disable a source
  without deleting it.

## The live preview

The right-hand column is a 360×800 Android phone showing exactly what this source's users
will see: the global settings with the form's values on top, read with the app's own rules.

- **Six screens:** Sign-in, Code, Paywall, UPI apps (the sheet), Processing and Web page.
  The rail beside the phone shows all of them live; click one to open it.
- **It follows the field you are in.** Clicking a field opens the screen it changes, scrolls
  the phone to it and outlines that part in orange. A field that is blank and so hidden in
  the app (tagline, rating, media, social proof) shows a dashed "appears here" box while
  focused. "UPI chooser label" switches the bottom bar to its no-UPI-app state.
- **All screens** shows the six phones side by side, all live. **Dark** shows the phone's
  dark theme. The slideshow moves every 2 s and the social-proof line every 3 s, as in the app.
- **Same sizes, colours and font as the app.** Every size comes from the Flutter widgets in
  `lib/screens/onboarding/`. The colours come from Google's material-color-utilities 0.3.0,
  which was checked against the Dart package Flutter uses and matches it hex for hex.
  The font is Roboto (the onboarding screens set no font).

Limits of the preview:

- The paywall video plays **muted** (browsers block sound on autoplay); "Sound" turns it on.
- The **web page** is loaded in a sandboxed frame. Sites that forbid being framed show
  the browser's "refused to connect" page; they still open in the app. "Open the site ↗" is
  under the phone.
- The keyboard, test-mode notices and error states are not drawn. The sample number
  (+91 98765 43210) and UPI apps (PhonePe, Google Pay, Paytm) are fixed.
- The colour library is bundled in `preview/vendor/` (the page runs no third-party
  script; see the CSP in `index.html`). A self-hosted Supabase (not `*.supabase.co`) must be
  added to the CSP's `connect-src`.

**Keep it in step with the app.** If `RemoteConfig.fromRows` or an onboarding screen changes,
change `preview/resolve.js` (and its tests) or `preview/screens.js` to match.
