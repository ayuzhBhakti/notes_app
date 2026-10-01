# Notes

A Flutter note-taking app. Sign in with Google, keep private text notes that sync through Cloud Firestore and work offline.

## Quick start

```sh
flutter pub get
flutter run
```

Google sign-in on Android needs your machine's debug SHA-1 registered in the Firebase project. See [docs/05-setup-and-build.md](docs/05-setup-and-build.md#android-signing-certificate).

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
- [Deep-link onboarding](docs/09-deep-link-onboarding.md)
- [AI agent context](docs/ai/AGENT_CONTEXT.md) and [task log](docs/ai/TASK_LOG.md)

Docs are updated in the same change as the code they describe.
