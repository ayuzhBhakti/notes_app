-- Every word, icon and colour on the paywall, editable in the Table Editor.
-- All public: they are what the screen shows. A blank text uses the app's
-- own; the values here are the app's defaults, so adding these rows changes
-- nothing on screen until one is edited.
--
-- Icons (paywall_feature_icons, paywall_social_proof_icon): an https link to
-- a small PNG or WebP, or one of the names in kPaywallIcons in
-- lib/screens/onboarding/paywall_screen.dart. paywall_feature_icons is
-- separated by |, one per feature, paired by position.
--
-- paywall_autopay_text is the sentence that says money is taken every month.
-- {trial} and {recurring} are replaced with the two prices from the amount
-- rows, so the words cannot drift from what is charged.
INSERT INTO public.app_config (key, value, is_public) VALUES
  ('paywall_video_aspect_ratio', '1:1', true),
  ('paywall_subtitle', '', true),
  ('paywall_feature_icons', '', true),
  ('paywall_show_strike_price', 'true', true),
  ('paywall_accent_color', '', true),
  ('paywall_autopay_text', '', true),
  ('paywall_social_proof_icon', '', true),
  ('paywall_cta_text', '', true),
  ('paywall_upi_select_text', '', true),
  ('paywall_upi_sheet_title', '', true)
ON CONFLICT (key) DO NOTHING;
