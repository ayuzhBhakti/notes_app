-- The paywall's preview video, as on the CashAlert paywall. An https URL to an
-- MP4 (H.264) file; blank shows paywall_preview_image_url, or no card at all.
INSERT INTO public.app_config (key, value, is_public) VALUES
  ('paywall_video_url', '', true)
ON CONFLICT (key) DO NOTHING;
