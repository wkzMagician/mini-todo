import 'app_services.dart';
import 'app_composition_native.dart'
    if (dart.library.js_interop) 'app_composition_web.dart'
    as platform;

export 'app_services.dart';

Future<AppServices> createApplicationServices() =>
    platform.createApplicationServices();
