import 'dart:async';

import 'package:dartloom_runtime/dartloom_runtime.dart';
import 'package:dartloom_singleton/dartloom_singleton.dart';
import 'package:flutter/widgets.dart';

import '../capabilities/capabilities.dart';
import 'app.dart';
import 'dartloom_factories.dart';
import 'resident_bootstrap.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDartloom(customFactories: dartloomApplicationFactories);
  // Desktop-only: if this process is a second launch, deliver the argv to the
  // primary instance, run any teardown, and exit instead of spawning a second
  // process that would own an independent full in-memory replica.
  await Dartloom.maybeGet<SingleInstanceService>()?.ensureSingleInstance();
  runApp(const DartloomApp());
  unawaited(
    configureResidentMenu().catchError((Object error, StackTrace stackTrace) {
      debugPrint('Failed to configure the resident menu: $error');
      debugPrintStack(stackTrace: stackTrace);
    }),
  );
}
