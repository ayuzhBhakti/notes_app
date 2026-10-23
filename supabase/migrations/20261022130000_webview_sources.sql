-- Per-source web page. The app loads a different webview_url depending on the
-- Play install referrer's utm_source (e.g. a link tagged utm_source=filmyface
-- opens the page saved here for 'filmyface'). A source with no row, an
-- inactive row, or an unattributed install (organic, or a phone with a work
-- account that makes Play strip the referrer) falls back to the global
-- app_config.webview_url row.
--
-- Read-only to the app, like app_config: edit rows in the Supabase Table
-- Editor. The 'source' key is the lowercased utm_source value.
CREATE TABLE IF NOT EXISTS public.webview_sources (
  source text PRIMARY KEY,
  webview_url text NOT NULL,
  is_active boolean NOT NULL DEFAULT true
);

COMMENT ON TABLE public.webview_sources IS
  'Per install-source web page. source = lowercased utm_source; the app overrides app_config.webview_url with the matching active row.';

ALTER TABLE public.webview_sources ENABLE ROW LEVEL SECURITY;

-- The only policy. An inactive row matches nothing, so the anon key cannot
-- read it; there is no write policy, so the app can never change these.
CREATE POLICY webview_sources_active_read ON public.webview_sources
  FOR SELECT TO anon, authenticated
  USING (is_active);

GRANT SELECT ON public.webview_sources TO anon, authenticated;

-- Example (left commented; fill real rows in the Table Editor):
-- INSERT INTO public.webview_sources (source, webview_url) VALUES
--   ('filmyface', 'https://filmyface.example.com/evos');
