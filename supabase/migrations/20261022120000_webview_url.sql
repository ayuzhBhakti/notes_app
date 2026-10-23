-- The page a subscriber (and the store-review account) lands on, shown in a
-- WebView where the maintenance screen used to be. An https URL; blank shows
-- a "come back soon" screen. maintenance_title and maintenance_message are no
-- longer read by the app and are left in place.
INSERT INTO public.app_config (key, value, is_public) VALUES
  ('webview_url', '', true)
ON CONFLICT (key) DO NOTHING;
