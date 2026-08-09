# Agent Instructions

This project is managed by Dartloom.

1. Read `dartloom.yaml` before changing infrastructure.
2. Feature code depends on capability contracts and obtains implementations with
   `Dartloom.get<T>(name: ...)`; do not import adapter packages in feature code.
3. Register app-owned implementations through `initializeDartloom` custom
   factories. Do not bypass or replace the generated registry wiring.
4. Business code belongs in `lib/features`; shared app glue belongs in `lib/app`.
5. Dartloom owns `lib/capabilities/capabilities.dart` and
   `lib/capabilities/bootstrap.dart`. Application files, including `lib/app`
   and ARB translations, are never overwritten by `dartloom project update`.

Before finishing, run `dart format .`, `flutter analyze`, and `flutter test`.
