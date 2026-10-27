-- Phase B of per-source app identity: the plan and prices.
--
-- A partner source can now set its own subscription plan and amounts, on top
-- of Phase A's visual identity. Same inherit/override rule as every other
-- column: NULL = inherit the global app_config value, non-NULL = override.
--
-- Stored as text, exactly like the app_config rows of the same name, so both
-- read paths treat them identically: the app's RemoteConfig.amount() and the
-- edge function's pickNumber() each parse the string and fall back to the
-- global value on anything invalid. The prices a customer is charged are read
-- SERVER-SIDE (create-cashfree-subscription -> loadAppConfig(installSource));
-- the device never sends an amount, only its install source.
--
-- These are still not secrets: the Cashfree id/secret live only in app_config
-- and are never columns of this table.

ALTER TABLE public.webview_sources
  ADD COLUMN IF NOT EXISTS plan_name                 text,
  ADD COLUMN IF NOT EXISTS cashfree_plan_id          text,
  ADD COLUMN IF NOT EXISTS cashfree_trial_amount     text,
  ADD COLUMN IF NOT EXISTS cashfree_recurring_amount text;

COMMENT ON TABLE public.webview_sources IS
  'Per install-source app identity. source = lowercased utm_source. The app overlays every non-NULL column onto app_config''s public rows (NULL = inherit). Prices/plan (Phase B) are also read server-side by create-cashfree-subscription.';
