-- Which ad each user came from, on their profile.
--
-- The app works out the ad (Meta ads decoded by the meta-install-referrer
-- function, Google Ads click ids, utm_* links) and saves it here after
-- sign-in through save_user_attribution. Server Mixpanel events (payments,
-- renewals, cancellations) read these columns so they can be broken down by
-- ad like the app's own events.
--
-- They hold the LATEST ad (last touch). A newer ad replaces the old one; an
-- organic or unknown install never replaces a known ad, so a reinstall from
-- the store keeps it. First touch lives on the Mixpanel profile (first_*).
--
-- profiles still has no insert or update policy for anon or authenticated:
-- the RPC below is the only way the app writes these columns, and it writes
-- only the caller's own row.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS install_source text,
  ADD COLUMN IF NOT EXISTS utm_source     text,
  ADD COLUMN IF NOT EXISTS utm_medium     text,
  ADD COLUMN IF NOT EXISTS utm_campaign   text,
  ADD COLUMN IF NOT EXISTS utm_term       text,
  ADD COLUMN IF NOT EXISTS utm_content    text,
  ADD COLUMN IF NOT EXISTS campaign_id    text,
  ADD COLUMN IF NOT EXISTS adset_id       text,
  ADD COLUMN IF NOT EXISTS ad_id          text,
  ADD COLUMN IF NOT EXISTS gclid          text,
  ADD COLUMN IF NOT EXISTS attributed_at  timestamptz;

COMMENT ON COLUMN public.profiles.install_source IS 'meta | google_ads | organic | other | unknown. Written by save_user_attribution only.';
COMMENT ON COLUMN public.profiles.utm_campaign IS 'Latest ad''s campaign. For Meta, the decoded campaign name.';
COMMENT ON COLUMN public.profiles.utm_term IS 'Latest ad''s ad set.';
COMMENT ON COLUMN public.profiles.utm_content IS 'Latest ad''s ad (creative) name: the main breakdown.';
COMMENT ON COLUMN public.profiles.ad_id IS 'Meta ad id, kept as text: 18 digits do not fit a JS number.';
COMMENT ON COLUMN public.profiles.gclid IS 'Google Ads click id, for a future Google Ads API lookup of the campaign.';

CREATE INDEX IF NOT EXISTS profiles_utm_source_attributed_at_idx
  ON public.profiles (utm_source, attributed_at);

-- Values are cut to a length no real campaign name reaches, so a crafted call
-- cannot bloat the row.
CREATE OR REPLACE FUNCTION public.save_user_attribution(
  p_install_source text,
  p_utm_source     text DEFAULT NULL,
  p_utm_medium     text DEFAULT NULL,
  p_utm_campaign   text DEFAULT NULL,
  p_utm_term       text DEFAULT NULL,
  p_utm_content    text DEFAULT NULL,
  p_campaign_id    text DEFAULT NULL,
  p_adset_id       text DEFAULT NULL,
  p_ad_id          text DEFAULT NULL,
  p_gclid          text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not signed in' USING ERRCODE = '42501';
  END IF;
  IF p_install_source IS NULL
     OR p_install_source NOT IN ('meta', 'google_ads', 'organic', 'other', 'unknown') THEN
    RAISE EXCEPTION 'invalid install_source' USING ERRCODE = '22023';
  END IF;

  IF p_install_source IN ('organic', 'unknown') THEN
    -- Never replaces a known ad; only fills a profile that has nothing yet.
    UPDATE profiles
       SET install_source = p_install_source,
           attributed_at  = now()
     WHERE id = v_uid
       AND install_source IS NULL;
    RETURN;
  END IF;

  UPDATE profiles
     SET install_source = p_install_source,
         utm_source     = left(nullif(btrim(p_utm_source), ''), 200),
         utm_medium     = left(nullif(btrim(p_utm_medium), ''), 200),
         utm_campaign   = left(nullif(btrim(p_utm_campaign), ''), 200),
         utm_term       = left(nullif(btrim(p_utm_term), ''), 200),
         utm_content    = left(nullif(btrim(p_utm_content), ''), 200),
         campaign_id    = left(nullif(btrim(p_campaign_id), ''), 40),
         adset_id       = left(nullif(btrim(p_adset_id), ''), 40),
         ad_id          = left(nullif(btrim(p_ad_id), ''), 40),
         gclid          = left(nullif(btrim(p_gclid), ''), 200),
         attributed_at  = now()
   WHERE id = v_uid;
END;
$$;

-- Supabase's default privileges grant EXECUTE to anon as well; take it back.
REVOKE ALL ON FUNCTION public.save_user_attribution(text, text, text, text, text, text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_user_attribution(text, text, text, text, text, text, text, text, text, text) TO authenticated;

-- Private rows (is_public = false): read only by edge functions with the
-- service role. The owner fills them in the Table Editor; blank = off.
INSERT INTO public.app_config (key, value, is_public) VALUES
  ('meta_install_referrer_key', '', false),  -- Meta App Dashboard -> Settings -> Basic -> Android, 64 hex chars
  ('mixpanel_token', '', false)              -- the same project token as res/values/analytics_keys.xml
ON CONFLICT (key) DO NOTHING;
