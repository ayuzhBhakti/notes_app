-- Lets the backend send Meta (Facebook) a server-side Purchase event for the real ₹299 monthly
-- debit, which happens while the app is closed, so the client can never fire it itself. The app
-- already sends a client-side StartTrial event for the ₹3 trial (AnalyticsChannel.kt); this is the
-- other half.
--
-- Meta needs an identifier to match the server event back to the install the ad brought. The
-- Facebook SDK already generates a stable per-app-install GUID with no extra permission or
-- consent flow (AppEventsLogger.getAnonymousAppDeviceGUID); the app sends it here once per
-- sign-in, and cashfree-webhook reads it back when a monthly payment succeeds.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS meta_anon_id text;

COMMENT ON COLUMN public.profiles.meta_anon_id IS
  'Facebook SDK per-app-install GUID (AppEventsLogger.getAnonymousAppDeviceGUID). Meta''s anon_id, sent with the server-side Purchase event for the real monthly debit. Written by save_meta_anon_id only.';

CREATE OR REPLACE FUNCTION public.save_meta_anon_id(p_anon_id text)
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
  IF p_anon_id IS NULL OR btrim(p_anon_id) = '' THEN
    RETURN;
  END IF;

  UPDATE profiles
     SET meta_anon_id = left(btrim(p_anon_id), 100)
   WHERE id = v_uid;
END;
$$;

-- Supabase's default privileges grant EXECUTE to anon as well; take it back.
REVOKE ALL ON FUNCTION public.save_meta_anon_id(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_meta_anon_id(text) TO authenticated;

-- Private rows (is_public = false): read only by edge functions with the service role. Made in
-- Events Manager: link the app to a dataset, then create an access token for it (Settings -> the
-- dataset's Generate Access Token). Blank = cashfree-webhook sends no Purchase event server-side.
INSERT INTO public.app_config (key, value, is_public) VALUES
  ('meta_capi_access_token', '', false),
  ('meta_capi_dataset_id', '', false)
ON CONFLICT (key) DO NOTHING;
