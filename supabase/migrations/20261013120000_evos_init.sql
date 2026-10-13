-- Backend for the deep-link (Evos) interface of the notes app.
--
--   app_config            -> settings edited in the Table Editor. Rows marked is_public are what
--                            the app reads (name, logo, colour, paywall text, prices). The rest,
--                            including the Cashfree id and secret, only edge functions can read.
--   profiles              -> one row per phone sign-in, holding the access gate.
--   subscription_payments -> append-only log of every charge.

-- ---------------------------------------------------------------------------
-- app_config
-- ---------------------------------------------------------------------------

CREATE TABLE public.app_config (
  key text PRIMARY KEY,
  value text NOT NULL DEFAULT '',
  is_public boolean NOT NULL DEFAULT false
);

COMMENT ON TABLE public.app_config IS 'App settings as key/value rows. Edit in the Supabase Table Editor.';
COMMENT ON COLUMN public.app_config.is_public IS 'True: sent to the app, so anyone can read it. Never set on a secret.';

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

-- The only policy. A row that is not public matches nothing, so the anon key in the app cannot
-- read the Cashfree secret however it asks. There is no insert, update or delete policy.
CREATE POLICY app_config_public_read ON public.app_config
  FOR SELECT TO anon, authenticated
  USING (is_public);

GRANT SELECT ON public.app_config TO anon, authenticated;

INSERT INTO public.app_config (key, value, is_public) VALUES
  -- Brand
  ('app_name', 'Evos', true),
  ('app_logo_url', '', true),                 -- https image; blank shows the first letter of the name
  ('theme_color', '#6D28D9', true),           -- #RRGGBB; the whole interface is tinted from it
  -- Paywall text. A blank row hides that part of the screen.
  ('paywall_title_prefix', '1-Day', true),
  ('paywall_title_badge', '', true),          -- blank shows the trial price, e.g. ₹3
  ('paywall_title_suffix', 'Trial', true),
  ('paywall_rating_value', '', true),         -- e.g. 4.6
  ('paywall_rating_caption', '', true),
  ('paywall_preview_image_url', '', true),
  ('paywall_features', 'Full access|Cancel anytime|Secure UPI AutoPay', true),  -- up to 4, split on |
  ('paywall_social_proofs', '', true),        -- rotating lines, split on |
  ('maintenance_title', 'We''re under maintenance', true),
  ('maintenance_message', 'Your subscription is active. We''ll be back soon, and there is nothing more you need to do.', true),
  -- Plan. The amounts are shown on the paywall and charged by create-cashfree-subscription.
  ('plan_name', 'Evos Premium Monthly', true),
  ('cashfree_plan_id', '', true),             -- blank: the plan is described inline from the amounts
  ('cashfree_trial_amount', '3', true),
  ('cashfree_recurring_amount', '299', true),
  -- Private: edge functions only.
  ('cashfree_app_id', '', false),
  ('cashfree_secret_key', '', false),
  ('cashfree_environment', 'sandbox', false), -- "production" takes real money
  -- SMS sign-in codes, read by sms-hook. The same three keys as CashAlert.
  ('fast2sms', '', false),                    -- Fast2SMS API key
  ('fast2sms_dlt_sender_id', '', false),
  ('fast2sms_dlt_te_id', '', false),          -- template (message) id
  ('send_sms_hook_secret', '', false),        -- shown by the dashboard when the Send SMS hook is saved
  ('customer_email_domain', '', false)        -- a domain you own; Cashfree needs an email per customer
ON CONFLICT (key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  phone text,
  subscription_status text NOT NULL DEFAULT 'none' CHECK (subscription_status = ANY (ARRAY[
    'none'::text,
    'pending'::text,
    'trial'::text,
    'active'::text,
    'cancelled'::text,
    'expired'::text
  ])),
  subscription_ends_at timestamptz,
  cashfree_subscription_id text,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON COLUMN public.profiles.subscription_status IS 'Access gate: none | pending | trial | active | cancelled | expired. Written by edge functions only.';

CREATE UNIQUE INDEX profiles_cashfree_subscription_id_idx
  ON public.profiles (cashfree_subscription_id)
  WHERE cashfree_subscription_id IS NOT NULL;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Read-only for its owner. With no insert or update policy a signed-in user cannot grant
-- themselves access; only the service role, which bypasses these policies, writes here.
CREATE POLICY profiles_select_own ON public.profiles
  FOR SELECT TO authenticated
  USING (auth.uid() = id);

GRANT SELECT ON public.profiles TO authenticated;

CREATE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, phone)
  VALUES (NEW.id, NEW.phone)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- What the app asks after sign-in and on every start. The rule lives here, once, and matches
-- isProfileAccessActive in supabase/functions/_shared/subscription.ts.
CREATE FUNCTION public.has_active_subscription()
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM profiles
    WHERE id = auth.uid()
      AND (
        (subscription_status IN ('trial', 'active')
          AND (subscription_ends_at IS NULL OR subscription_ends_at > now()))
        -- Cancelled keeps access until the period already paid for runs out.
        OR (subscription_status = 'cancelled' AND subscription_ends_at > now())
      )
  );
$$;

REVOKE ALL ON FUNCTION public.has_active_subscription() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.has_active_subscription() TO authenticated;

-- ---------------------------------------------------------------------------
-- subscription_payments
-- ---------------------------------------------------------------------------

CREATE TABLE public.subscription_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  phone text,
  payment_id text NOT NULL,
  cashfree_subscription_id text,
  payment_method text NOT NULL DEFAULT 'upi',
  amount numeric(10, 2) NOT NULL CHECK (amount > 0),
  plan_type text NOT NULL CHECK (plan_type = ANY (ARRAY['trial'::text, 'monthly'::text])),
  status text NOT NULL DEFAULT 'success' CHECK (status = ANY (ARRAY[
    'pending'::text,
    'success'::text,
    'failed'::text
  ])),
  paid_at timestamptz,
  plan_ends_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.subscription_payments IS 'Append-only log of subscription charges (trial authorisation and monthly debits).';

-- Also what makes a repeated webhook harmless: the second insert of a payment is rejected.
CREATE UNIQUE INDEX subscription_payments_payment_id_idx
  ON public.subscription_payments (payment_id);

CREATE INDEX subscription_payments_user_id_created_at_idx
  ON public.subscription_payments (user_id, created_at DESC);

CREATE INDEX subscription_payments_cashfree_subscription_id_idx
  ON public.subscription_payments (cashfree_subscription_id)
  WHERE cashfree_subscription_id IS NOT NULL;

ALTER TABLE public.subscription_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY subscription_payments_select_own ON public.subscription_payments
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

GRANT SELECT ON public.subscription_payments TO authenticated;
