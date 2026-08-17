# Agent Instructions

This project uses the current Dartloom package-configurator model.

- Read `.dartloom/project.yaml` before changing platform or dependency setup.
- Dartloom does not provide a runtime framework in this project. Do not add
  `dartloom_runtime`, generated capabilities, service locators, or migration
  commands.
- The application composition root is `lib/app/app_composition.dart` and its
  platform implementations. It constructs direct Dartloom package instances
  and passes them into features explicitly.
- Business code belongs in `lib/features`; shared composition and lifecycle
  code belongs in `lib/app`.
- Use `dartloom new`, `dartloom update`, and `dartloom check` only for package
  selection and platform metadata. They must not be expected to generate app
  source code.
- The current Dartloom monorepo uses unpublished schema-6 package constraints.
  Keep the direct Git references and their matching `dependency_overrides` in
  `pubspec.yaml` until upstream publishes compatible package versions.

Before finishing, run `dart format .`, `flutter analyze`, and `flutter test`.

<!-- dartloom:begin -->
## Dartloom packages

Selected platforms: Android, Ios, Windows, Macos, Linux, Web

No optional Dartloom packages are selected.
<!-- dartloom:end -->
