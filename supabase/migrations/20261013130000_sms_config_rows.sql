-- The SMS settings rows, for a database that got 20261013120000 before they were
-- added to it. Harmless where they already exist.
INSERT INTO public.app_config (key, value, is_public) VALUES
  ('fast2sms', '', false),                    -- Fast2SMS API key
  ('fast2sms_dlt_sender_id', '', false),
  ('fast2sms_dlt_te_id', '', false),          -- template (message) id
  ('send_sms_hook_secret', '', false)         -- shown by the dashboard when the Send SMS hook is saved
ON CONFLICT (key) DO NOTHING;
