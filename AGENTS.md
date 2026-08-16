# Agent Instructions

This project is managed by Dartloom.

Dartloom repository: https://github.com/wkzMagician/dartloom

## Dartloom commands

Install or refresh the CLI:

```bash
dart install --overwrite https://github.com/wkzMagician/dartloom.git --git-path cli/dartloom_cli
```

Upgrade Dartloom-managed project files and dependencies:

```bash
dartloom project upgrade
```

Check the project and build a Windows release package:

```bash
dartloom check
dartloom package windows exe
```

1. Read `dartloom.yaml` before changing infrastructure.
2. Feature code depends on capability contracts and obtains implementations with
   `Dartloom.get<T>(name: ...)`; do not import adapter packages in feature code.
3. Register app-owned implementations by passing their factory map to
   `bootstrapDartloom(customFactories: ...)`. Keep factory implementations in
   application-owned files; do not add them to generated capability files.
4. Business code belongs in `lib/features`; shared app glue belongs in `lib/app`.
5. Dartloom owns `lib/capabilities/capabilities.dart` and
   `lib/capabilities/bootstrap.dart`. Application files, including `lib/app`
   and ARB translations, are never overwritten by `dartloom project upgrade`.

## Capability platform support

Enabled project targets: android, windows, macos, linux.

Generated registration is platform-aware. Treat a capability as optional when
the current target is not listed below, and use `Dartloom.maybeGet<T>()` for
optional feature UI instead of duplicating operating-system checks.

| Capability instance | Contract package | Implementation | Project targets |
| --- | --- | --- | --- |
| `settings.default` | `dartloom_settings` | `shared_preferences` | android, windows, macos, linux |
| `settings.sync_secrets` | `dartloom_settings` | `secure_storage` | android, windows, macos, linux |
| `storage.json` | `dartloom_storage` | `app_file_replica` | android, windows, macos, linux |
| `logging.default` | `dartloom_logging` | `logger` | android, windows, macos, linux |
| `autostart.default` | `dartloom_autostart` | `launch_at_startup` | windows, macos, linux |
| `sync.default` | `dartloom_sync` | `etag` | android, windows, macos, linux |
| `localization.default` | `dartloom_localization` | `gen_l10n` | android, windows, macos, linux |
| `resident.default` | `dartloom_resident` | `tray` | windows, macos, linux |
| `singleton.default` | `dartloom_singleton` | `socket` | windows, macos, linux |

## Sync policy by platform

Startup, resume, local-write, connectivity, polling, retry, conflict, and
background behavior is owned by Dartloom. Feature code calls `SyncService`
and must not reproduce these triggers.

| Sync instance | Platform | Mode | Remote discovery | Poll interval | System background |
| --- | --- | --- | --- | --- | --- |
| `sync.default` | android | automatic | auto | 5m | enabled |
| `sync.default` | windows | automatic | auto | 5m | disabled |
| `sync.default` | macos | automatic | auto | 5m | disabled |
| `sync.default` | linux | automatic | auto | 5m | disabled |


Before finishing, run `dart format .`, `flutter analyze`, and `flutter test`.
