// Supabase project behind the deep-link interface: phone sign-in, the
// settings in app_config, and the Cashfree subscription functions.
//
// The Evos project is the default, so a plain `flutter run` or `flutter build`
// talks to it. Either value can be replaced at build time:
//
//   flutter run \
//     --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
//     --dart-define=SUPABASE_ANON_KEY=<publishable key>
//
// Passing an empty URL turns the backend off, which in a debug build is test
// mode (no SMS, the code is 123456, simulated payment):
//
//   flutter run --dart-define=SUPABASE_URL=
//
// The publishable key is safe to ship in an app. What protects the data is
// row-level security: anon can read only the app_config rows marked public,
// and a signed-in user only their own profile. The Cashfree id and secret
// are private rows that only edge functions can read. Never put a secret or
// service-role key here. See docs/09-deep-link-onboarding.md.
const String kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://sqvlgiqypqvjykczuhgz.supabase.co',
);
const String kSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_fwrQXYrua2ld2NOijHgdsg_MYdJ4Ieb',
);

bool get isSupabaseConfigured =>
    kSupabaseUrl.isNotEmpty && kSupabaseAnonKey.isNotEmpty;
