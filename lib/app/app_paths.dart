import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final class MiniTodoPaths {
  const MiniTodoPaths({required this.businessRoot, required this.metadataRoot});

  final Directory businessRoot;
  final Directory metadataRoot;

  static Future<MiniTodoPaths> resolve() async {
    final support = (await getApplicationSupportDirectory()).absolute;
    return MiniTodoPaths(
      businessRoot: Directory(p.join(support.path, 'MiniTodo')).absolute,
      metadataRoot: Directory(
        p.join(support.path, 'mini_todo', 'sync-metadata', 'MiniTodo'),
      ).absolute,
    );
  }
}
