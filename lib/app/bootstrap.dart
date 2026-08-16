import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app.dart';
import 'app_composition.dart';
import 'resident_bootstrap.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await createApplicationServices();
  await services.singleInstance?.ensureSingleInstance();
  runApp(
    MiniTodoApp(
      repository: services.repository,
      settings: services.settings,
      autostart: services.autostart,
      logger: services.logger,
      syncService: services.sync,
    ),
  );
  unawaited(
    configureResidentMenu(services.resident).catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      debugPrint('Failed to configure the resident menu: $error');
      debugPrintStack(stackTrace: stackTrace);
    }),
  );
}
