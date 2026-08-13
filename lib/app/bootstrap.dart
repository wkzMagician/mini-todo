import 'package:flutter/widgets.dart';

import '../capabilities/capabilities.dart';
import 'app.dart';
import 'dartloom_factories.dart';
import 'resident_bootstrap.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDartloom(customFactories: dartloomApplicationFactories);
  await configureResidentMenu();
  runApp(const DartloomApp());
}
