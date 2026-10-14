-- The carousel on the mobile-number screen, as on the CashAlert login screen.
-- Two lists split on |, paired by position: the first title goes with the
-- first image. Images are https links; blank images hide the carousel.
INSERT INTO public.app_config (key, value, is_public) VALUES
  ('login_slide_images', '', true),
  ('login_slide_titles', '', true)
ON CONFLICT (key) DO NOTHING;
