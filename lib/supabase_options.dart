// Supabase project that receives the onboarding form.
//
// Supplied at build time so no project is baked into the source:
//
//   flutter run \
//     --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
//     --dart-define=SUPABASE_ANON_KEY=<anon key>
//
// The anon key is safe to ship in an app. What protects the data is the
// table's row-level security, which must allow anon to INSERT and nothing
// else. See docs/09-deep-link-onboarding.md.
const String kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String kSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

bool get isSupabaseConfigured =>
    kSupabaseUrl.isNotEmpty && kSupabaseAnonKey.isNotEmpty;
