import 'package:flutter/widgets.dart';

import 'capabilities.dart';

/// Dartloom-owned startup fragment. Call this from the application's main
/// method before creating its widget tree.
Future<void> bootstrapDartloom() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDartloom();
}
