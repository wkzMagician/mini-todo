# Dartloom v2 refactor notes

Date: 2026-08-07

## What changed in Mini Todo

- Migrated `dartloom.yaml` from schema v1 flags to schema v2 named instances.
- Replaced the application-owned file settings store with the configured
  `SettingsStore` adapter (`shared_preferences`).
- Replaced the application-owned JSON file persistence with the configured
  `JsonStore` adapter. Todo records are stored under the `todos` key.
- Removed unused `LocalStore` and `SyncEngine` plumbing. Sync was previously
  configured as a no-op and had neither a backend configuration nor a UI flow.
- Kept the Todo domain, controller and widgets in `lib/features`, using
  capability contracts obtained through `Dartloom.get<T>()` when production
  collaborators are not supplied.
- Kept title-bar window commands and the Mini Todo tray menu in `lib/app`.
  The resident service itself is still created by Dartloom before `runApp`.
- Restored the Mini Todo ARB strings after the managed template reset them to
  the generic starter application strings.

## Dartloom observations

### 1. Project update can generate against a newer API than the active lockfile

`dartloom project update` rewrote the generated registry to use v2 contracts
such as `JsonStore`, but the existing `pubspec.lock` still resolved the v1 Git
commits. The update command ran `pub get`, which retained those locked commits,
and then its own `flutter analyze` failed with missing contract types.

Workaround used here: run `flutter pub upgrade` after `project update` so the
Git overrides resolve to the current Dartloom commit.

Suggested Dartloom change: when upgrading contract major versions from GitHub,
run `flutter pub upgrade` (or detect incompatible locked package versions and
emit an actionable instruction) before running analysis.

### 2. Managed `app.dart` and ARB files overwrite application behavior

The update command overwrites `lib/app/app.dart`, `lib/app/bootstrap.dart` and
both application ARB files with a generic starter shell. This is risky for an
existing application because app-specific routing, themes, lifecycle glue and
translations disappear before the project can compile again.

Suggested Dartloom change: generate only a narrowly scoped registry/bootstrap
file, or offer an opt-in template refresh. If these files remain managed, the
CLI should preserve application regions or create a migration backup.

### 3. ResidentService does not expose menu or click-policy customization

`ResidentService` provides initialize, restore, quit and dispose only. Mini
Todo needs a persistent tray context menu with a “Quit completely” action. The
official tray adapter also restores the window on left click by default, which
conflicts with showing that menu. The app therefore needs adapter-specific
glue to replace its tray listener while retaining its close-to-tray listener.

Suggested Dartloom change: add a platform-neutral resident menu/click-policy
contract, or make the official tray adapter accept a menu definition and
click behavior through configuration.

### 4. Platform capability activation is not conditional at runtime

The schema allows an app to target mobile and desktop while enabling
`resident`, but generated initialization creates every configured adapter on
every target. The tray adapter is desktop-only in practice, so a mixed-target
application needs custom platform guards despite a valid configuration.

Suggested Dartloom change: support per-platform capability instances or skip
unsupported adapters during generated initialization with an explicit,
testable fallback.

## Data migration note

The new JSON adapter stores data in the application-support directory as a
keyed JSON document. Previous Mini Todo versions stored a standalone list in
the user data directory. This refactor intentionally starts with the new
store; a one-time importer can be added if existing user data must be carried
forward in a release.

## Dartloom update follow-up (2026-08-08)

The Dartloom update at commit `c752f98` addresses three observations above:

- capability updates preserve application-owned app code and provide a managed
  `lib/capabilities/bootstrap.dart` startup fragment;
- `ResidentService` now supports menu entries, click behavior and callbacks;
- generated registrations skip adapters that do not support the current
  platform.

Mini Todo now configures its tray menu through `ResidentService.configure()`.
It no longer imports `tray_manager` or the concrete `TrayResidentService` in
application code. The remaining native window channel and Win32 window style
are intentionally application-specific: they implement Mini Todo's frameless,
topmost, collapsible window design rather than a reusable capability.

## Resolution (2026-08-08)

The Flutter SDK was a healthy official Git checkout. The apparent toolchain
failure was caused by an orphaned Flutter daemon retaining
`bin/cache/flutter.bat.lock` and `bin/cache/lockfile`; all later Flutter
commands waited on those locks without producing output. Stopping that stale
daemon and removing only the two regenerated lock files restored the CLI.

The Dartloom CLI now makes GitHub capability overrides explicitly follow
`main`, and `dartloom project update` uses
`flutter --no-version-check pub upgrade` to refresh the dependency lock before
analysis. Mini Todo's lock now resolves all Dartloom packages to
`c752f989703031fb9ea15609d79a9b4bfd6ee8f7` on `main`.

Validation after the update: `flutter analyze` reported no issues and all six
Flutter tests passed.
