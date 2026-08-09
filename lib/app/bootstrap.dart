import 'package:flutter/widgets.dart';

import '../capabilities/bootstrap.dart';
import 'app.dart';
import 'resident_bootstrap.dart';

Future<void> bootstrap() async {
  await bootstrapDartloom();
  await configureResidentMenu();
  runApp(const DartloomApp());
}
