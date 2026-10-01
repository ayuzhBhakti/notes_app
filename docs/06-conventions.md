# Conventions

These describe how the existing code is written. New code should match.

## Dart style

- **Explicit types everywhere.** Locals, provider declarations, closure parameters and collection literals are all typed: `final ThemeData theme = ...`, `<Widget>[...]`, `(Ref ref) => ...`.
- **`const` constructors** wherever possible.
- **Relative imports** inside `lib/`. Package imports first, then a blank line, then relative imports.
- **Private widgets** (`_Banner`, `_EmptyView`, `_ErrorView`) live in the file of the screen that uses them. Move a widget to `lib/widgets/` only when a second screen needs it.
- **Lints:** `flutter_lints` defaults with no overrides. `flutter analyze` must report no issues.

## Comments

Comments explain why, not what. The typical comment in this codebase records a decision or a trap: why a future is not awaited, why a field is nullable, what a plugin version changed. Keep that standard. Do not add comments that restate the code.

## State management

- Declare providers by hand in [lib/providers.dart](../lib/providers.dart). No `riverpod_generator`.
- Use `ref.watch` in `build` and `ref.read` in callbacks.
- Data is exposed through stream or plain providers. Mutations go through an `AsyncNotifier` whose state is only loading/error status.
- Mutation methods return `Future<bool>` for success, and the screen reads the error from the provider when it is false.
- Use `skipLoadingOnReload: true` on `AsyncValue.when` for anything downstream of auth, or the screen flashes a spinner when the auth stream re-emits.
- Riverpod 3 specifics: there is no `.valueOrNull`; `.value` is null during loading and error. Failed providers retry automatically unless `retry:` is overridden.

## Screens and async code

- Capture `Navigator.of(context)` and `ScaffoldMessenger.of(context)` **before** any async gap, then use the captured objects.
- Do not await a Firestore write before popping a screen. Use `unawaited(...)` and report failure in `.then`. Awaiting would hang the screen while offline.
- Do await a Supabase write, and show a busy state while it runs. It has no offline cache, so success is only known when the server answers.
- Never navigate in response to sign-in, sign-out or an onboarding stage change. `AuthGate` and `AppGate` handle it.
- Do not give `MaterialApp` a `home`, and do not move `DeepLinkService.start()` after `runApp`. Both break deep links; the reasons are in [09-deep-link-onboarding.md](09-deep-link-onboarding.md#receiving-the-direct-link).

## Data access

- Screens and widgets do not call Firebase SDKs. They use providers, which use `AuthService` and `NotesRepository`.
- Repository methods take `uid` as their first argument.
- All timestamps written to Firestore are `FieldValue.serverTimestamp()`.
- Only [onboarding_store.dart](../lib/services/onboarding_store.dart) imports `shared_preferences`, and only [leads_repository.dart](../lib/services/leads_repository.dart) imports `supabase`. Screens reach payment only through `PaymentGateway`.
- Use the pure-Dart `supabase` package. Do not add `supabase_flutter`; its deep-link plugin conflicts with `DeepLinkService`.
- A Supabase table written with the anon key gets an insert-only policy. Never add a select, update or delete policy for `anon`.
- A new Firestore field needs three changes together: [firestore.rules](../firestore.rules) (both the `hasOnly` and `hasAll` lists), [note.dart](../lib/models/note.dart), and [notes_repository.dart](../lib/services/notes_repository.dart). Then the rules must be published.

## Errors

- Anything shown to the user goes through `describeError` in [lib/utils/errors.dart](../lib/utils/errors.dart). Add new cases there instead of formatting messages in a screen.
- Messages are plain sentences. The optional hint says what to check.
- Debug-only diagnostics use `debugPrint` behind `kDebugMode`, prefixed with a tag such as `[auth]`.

## Dependencies

Prefer a few lines of code over a new package. `intl` was left out on purpose in favour of [format.dart](../lib/utils/format.dart), and deep links are read from the framework instead of through a plugin. Adding a package needs a reason, recorded in the task log.

## Tests

- Pure logic (models, formatters, mappers, validators) gets unit tests in `test/`.
- Screens that do not need a signed-in user get widget tests that pump `NotesApp` with provider overrides, as in [onboarding_flow_test.dart](../test/onboarding_flow_test.dart).
- User-visible behaviour gets a Maestro flow in `.maestro/flows/`. Each flow starts with `ensure_signed_in`, uses a unique note title, and deletes what it creates.
- A control with no visible text gets `Semantics(identifier: 'snake_case_name')`. Do not select on tooltips or hint text.
- Before renaming user-visible text or an identifier, search `.maestro/` for it.
- Before finishing a task, run `flutter analyze` and `flutter test`. Run the Maestro flows when a device is connected and the change touches a screen.

## Git

- `main` is the only branch so far, with one commit.
- Commit only when asked. Branch off `main` before committing new work.
