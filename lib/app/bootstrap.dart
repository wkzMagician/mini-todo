import 'package:flutter/widgets.dart';

import '../capabilities/capabilities.dart';
import 'app.dart';
import 'resident_bootstrap.dart';
import 'sync_factory.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDartloom(customFactories: {'app_sync': createAppSync});
  await configureResidentMenu();
  runApp(const DartloomApp());
}
