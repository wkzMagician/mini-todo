import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'app_composition.dart';
import 'resident_bootstrap.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _LaunchingApp());

  try {
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
  } catch (error, stackTrace) {
    debugPrint('Failed to initialize Mini Todo: $error');
    debugPrintStack(stackTrace: stackTrace);
    runApp(_LaunchFailureApp(error: error));
  }
}

class _LaunchingApp extends StatelessWidget {
  const _LaunchingApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: Center(child: CircularProgressIndicator())),
  );
}

class _LaunchFailureApp extends StatelessWidget {
  const _LaunchFailureApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Mini Todo could not start.',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(onPressed: bootstrap, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    ),
  );
}
