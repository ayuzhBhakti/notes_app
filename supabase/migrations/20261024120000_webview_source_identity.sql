-- Phase A of per-source app identity.
--
-- Until now webview_sources held only the per-source web page (source,
-- webview_url, is_active). A partner source now carries the whole *visual*
-- identity too: name, logo, theme colour, every paywall text/media field and
-- the login carousel. The app overlays these on top of the global app_config
-- public rows, so one install source behaves like a separate white-label app.
--
-- Inherit vs. override: a NULL column means "inherit the global app_config
-- value"; a non-NULL column (even an empty string) overrides it, and an empty
-- string is a real answer that hides that part of the screen, exactly as a
-- blank app_config row does. So organic installs and any column left NULL fall
-- straight through to app_config.
--
-- The column names are the matching app_config keys verbatim, so the app can
-- overlay them generically (see EvosBackend.fetchConfig / _applySourceOverrides)
-- and a column added later needs no code change on the read path.
--
-- Prices and the plan (cashfree_trial_amount, cashfree_recurring_amount,
-- cashfree_plan_id, plan_name) are deliberately NOT here: they are read
-- server-side by create-cashfree-subscription and are Phase B. This migration
-- never touches the payment path.
--
-- Secrets are not columns of this table and can never become per-source. The
-- table stays read-only to the app (no write policy); the admin panel writes
-- through the admin-source-config edge function with the service role.

-- webview_url was NOT NULL when the table held only the per-source page. It is
-- now one override column among many, so NULL must mean "inherit the global
-- app_config.webview_url" like every other column; drop the constraint.
ALTER TABLE public.webview_sources
  ALTER COLUMN webview_url DROP NOT NULL;

ALTER TABLE public.webview_sources
  ADD COLUMN IF NOT EXISTS app_name                   text,
  ADD COLUMN IF NOT EXISTS app_logo_url               text,
  ADD COLUMN IF NOT EXISTS theme_color                text,
  ADD COLUMN IF NOT EXISTS paywall_accent_color       text,
  ADD COLUMN IF NOT EXISTS paywall_title_prefix       text,
  ADD COLUMN IF NOT EXISTS paywall_title_badge        text,
  ADD COLUMN IF NOT EXISTS paywall_title_suffix       text,
  ADD COLUMN IF NOT EXISTS paywall_subtitle           text,
  ADD COLUMN IF NOT EXISTS paywall_rating_value       text,
  ADD COLUMN IF NOT EXISTS paywall_rating_caption     text,
  ADD COLUMN IF NOT EXISTS paywall_preview_image_url  text,
  ADD COLUMN IF NOT EXISTS paywall_video_url          text,
  ADD COLUMN IF NOT EXISTS paywall_video_aspect_ratio text,
  ADD COLUMN IF NOT EXISTS paywall_features           text,
  ADD COLUMN IF NOT EXISTS paywall_feature_icons      text,
  ADD COLUMN IF NOT EXISTS paywall_social_proofs      text,
  ADD COLUMN IF NOT EXISTS paywall_social_proof_icon  text,
  ADD COLUMN IF NOT EXISTS paywall_show_strike_price  boolean,
  ADD COLUMN IF NOT EXISTS paywall_cta_text           text,
  ADD COLUMN IF NOT EXISTS paywall_autopay_text       text,
  ADD COLUMN IF NOT EXISTS paywall_upi_select_text    text,
  ADD COLUMN IF NOT EXISTS paywall_upi_sheet_title    text,
  ADD COLUMN IF NOT EXISTS login_slide_images         text,
  ADD COLUMN IF NOT EXISTS login_slide_titles         text;

COMMENT ON TABLE public.webview_sources IS
  'Per install-source app identity. source = lowercased utm_source. The app overlays every non-NULL column onto app_config''s public rows (NULL = inherit). Prices/plan are Phase B and live in app_config only.';

-- The existing SELECT policy (is_active) and the GRANT already cover the new
-- columns; a GRANT SELECT is table-wide. Nothing to change for the read path.

-- ---------------------------------------------------------------------------
-- Admin panel secret.
-- ---------------------------------------------------------------------------
-- Private (is_public = false), so the app's anon key can never read it, like
-- the Cashfree secret. The admin-source-config edge function reads it with the
-- service role and compares it to the panel's x-admin-secret header. A blank
-- value must make that function refuse every request (no empty-secret access);
-- fill a strong value in the Supabase Table Editor before using the panel.
INSERT INTO public.app_config (key, value, is_public) VALUES
  ('admin_panel_secret', '', false)
ON CONFLICT (key) DO NOTHING;
