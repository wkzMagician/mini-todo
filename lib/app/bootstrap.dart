import 'dart:async';

import 'package:flutter/widgets.dart';

import '../capabilities/capabilities.dart';
import 'app.dart';
import 'dartloom_factories.dart';
import 'resident_bootstrap.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDartloom(
    customFactories: dartloomApplicationFactories,
    ensureSingleInstance: true,
  );
  runApp(const DartloomApp());
  unawaited(
    configureResidentMenu().catchError((Object error, StackTrace stackTrace) {
      debugPrint('Failed to configure the resident menu: $error');
      debugPrintStack(stackTrace: stackTrace);
    }),
  );
}
