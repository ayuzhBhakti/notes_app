# Notes app documentation

Start here. Every document in this folder describes the code as it actually is, and each one is updated in the same change as the code it describes.

## Reading order

| # | Document | Read it when you need to know |
|---|----------|-------------------------------|
| 1 | [Overview](01-overview.md) | What the app does, the tech stack, which platforms work |
| 2 | [Architecture](02-architecture.md) | Layers, folder layout, the provider graph, import rules |
| 3 | [App flow](03-app-flow.md) | Startup, sign-in, notes create/edit/delete, navigation |
| 4 | [Data model](04-data-model.md) | Firestore schema, security rules, timestamp behaviour |
| 5 | [Setup and build](05-setup-and-build.md) | How to run, build, test, and fix common build failures |
| 6 | [Conventions](06-conventions.md) | Code style and the patterns new code must follow |
| 7 | [Known issues](07-known-issues.md) | Bugs, gaps and tech debt found so far |
| 8 | [End-to-end testing](08-e2e-testing.md) | Running and writing Maestro flows against a real device |
| 9 | [Deep-link onboarding](09-deep-link-onboarding.md) | The Evos interface shown to users who arrive by link: phone sign-in, paywall, maintenance; the Supabase backend and its settings; Cashfree; App Links setup |
| 10 | [Analytics](10-analytics.md) | Every Mixpanel and Facebook event, what triggers it, and where the keys go |
| — | [Ad attribution guide](DEEPLINK_GUIDE.md) | For the team: making campaign links, which ad each user came from, Mixpanel funnels by ad, the after-release check |
| — | [Admin panel guide](ADMIN_PANEL_GUIDE.md) | For admins, in plain words: unlocking the panel, adding a source, what each field changes, the rules, install links |
| — | [Mixpanel events guide](MIXPANEL_EVENTS_GUIDE.md) | For the team, in plain words: every app and server event, the ad fields on each, ready-made reports |

## For AI agents

| Document | Purpose |
|----------|---------|
| [ai/AGENT_CONTEXT.md](ai/AGENT_CONTEXT.md) | Condensed project context. Loaded automatically through the root `CLAUDE.md` and `AGENTS.md`. |
| [ai/TASK_LOG.md](ai/TASK_LOG.md) | One entry per completed task: what changed, why, and how it was verified. |

## Keeping these docs current

Docs are part of the definition of done. A task is not finished until the docs match the code.

After every task:

1. Add an entry to [ai/TASK_LOG.md](ai/TASK_LOG.md), newest first.
2. Update each document the change touches, using the table below.
3. If a fact in [ai/AGENT_CONTEXT.md](ai/AGENT_CONTEXT.md) is no longer true, fix it there too. It is the file agents trust first.

| If you changed | Update |
|----------------|--------|
| A screen, a route, or what the user sees | [03-app-flow.md](03-app-flow.md), and the Maestro flows in `.maestro/` that select on it |
| A Maestro flow or a semantics identifier | [08-e2e-testing.md](08-e2e-testing.md) |
| The onboarding flow, the link, payment, what is stored on the device, or anything in `supabase/` (a table, a policy, an `app_config` key, an edge function) | [09-deep-link-onboarding.md](09-deep-link-onboarding.md) |
| An analytics event, property, or key | [10-analytics.md](10-analytics.md), [MIXPANEL_EVENTS_GUIDE.md](MIXPANEL_EVENTS_GUIDE.md) |
| A field, rule or screen of the admin panel (`admin/`) | [ADMIN_PANEL_GUIDE.md](ADMIN_PANEL_GUIDE.md) and `admin/README.md` |
| A provider, a service, a folder, or an import rule | [02-architecture.md](02-architecture.md), [ai/AGENT_CONTEXT.md](ai/AGENT_CONTEXT.md) |
| A Firestore field, collection, query, or `firestore.rules` | [04-data-model.md](04-data-model.md) |
| A dependency, SDK version, Gradle or Xcode setting | [01-overview.md](01-overview.md), [05-setup-and-build.md](05-setup-and-build.md) |
| A feature added or removed | [01-overview.md](01-overview.md), [03-app-flow.md](03-app-flow.md) |
| A new pattern or a rule other code must follow | [06-conventions.md](06-conventions.md), [ai/AGENT_CONTEXT.md](ai/AGENT_CONTEXT.md) |
| What data the app collects, an SDK or service that receives it, or anything a user sees in the app | `website/privacy-policy.html` and the other pages in `website/` that describe it |
| A CSS or JS file in `website/` | The `?v=` value in every `website/*.html` page ([05-setup-and-build.md](05-setup-and-build.md#website-upload-hostinger)) |
| A bug fixed, or a new bug or gap found | [07-known-issues.md](07-known-issues.md) |

Rules for writing here:

- Describe what the code does today. Plans and ideas go in [07-known-issues.md](07-known-issues.md), not in the descriptive docs.
- Link to source files instead of pasting code, so the docs cannot drift from it.
- Say when something was checked by reading the code only and not by running it.
- Delete statements that are no longer true. Do not leave them with a "deprecated" note.
