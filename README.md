# Evos

A Flutter subscription app. Sign in with a mobile number and SMS code (Supabase), subscribe through Cashfree UPI AutoPay, then use a web page inside the app. It began as a notes app; the notes code is still here but unreachable.

## Quick start

```sh
flutter pub get
flutter run
```

`flutter run` talks to the real backend and sends real SMS. For test mode (no SMS, code 123456, simulated payment) use `flutter run --dart-define=SUPABASE_URL=`. See [docs/09-deep-link-onboarding.md](docs/09-deep-link-onboarding.md).

## Documentation

Everything is in [docs/](docs/README.md):

- [Overview](docs/01-overview.md)
- [Architecture](docs/02-architecture.md)
- [App flow](docs/03-app-flow.md)
- [Data model](docs/04-data-model.md)
- [Setup and build](docs/05-setup-and-build.md)
- [Conventions](docs/06-conventions.md)
- [Known issues](docs/07-known-issues.md)
- [End-to-end testing](docs/08-e2e-testing.md)
- [Phone sign-in, paywall and web page](docs/09-deep-link-onboarding.md)
- [Analytics](docs/10-analytics.md)
- [AI agent context](docs/ai/AGENT_CONTEXT.md) and [task log](docs/ai/TASK_LOG.md)

Docs are updated in the same change as the code they describe.
