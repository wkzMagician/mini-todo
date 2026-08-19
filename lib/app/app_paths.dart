import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final class MiniTodoPaths {
  const MiniTodoPaths({required this.businessRoot, required this.metadataRoot});

  final Directory businessRoot;
  final Directory metadataRoot;

  static Future<MiniTodoPaths> resolve() async {
    final support = (await getApplicationSupportDirectory()).absolute;
    final businessRoot = Directory(
      p.join(support.path, 'business_data'),
    ).absolute;
    final metadataRoot = Directory(
      p.join(support.path, 'sync_metadata'),
    ).absolute;

    // Migrate from legacy single MiniTodo directory if needed.
    final legacyBusiness = Directory(p.join(support.path, 'MiniTodo')).absolute;
    if (!await businessRoot.exists() && await legacyBusiness.exists()) {
      await businessRoot.create(recursive: true);
      await for (final entity in legacyBusiness.list(followLinks: false)) {
        final name = p.basename(entity.path);
        // Do not copy any legacy nested metadata directories
        if (name.toLowerCase() == 'sync-metadata' ||
            name.toLowerCase() == 'mini_todo' ||
            name.startsWith('.')) {
          continue;
        }
        if (entity is File) {
          await entity.copy(p.join(businessRoot.path, name));
        }
      }
    }

    return MiniTodoPaths(
      businessRoot: businessRoot,
      metadataRoot: metadataRoot,
    );
  }
}
