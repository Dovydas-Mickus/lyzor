import 'dart:io';

import 'package:lyzor/lyzor.dart';
import 'package:path/path.dart' as p;

extension LyzorStatic on Lyzor {
  void static(String routePath, String fileSystemPath, {bool listDirectories = true}) {
    final absoluteRoot = p.canonicalize(Directory(fileSystemPath).absolute.path);

    final prefix = routePath.endsWith('/') ? routePath.substring(0, routePath.length - 1) : routePath;

    route('$prefix/*').get(() async {
      final ctx = Context.current;

      final subPath = ctx.pathParams['*'] ?? '';

      final fullPath = p.canonicalize(p.join(absoluteRoot, subPath));

      if (!fullPath.startsWith(absoluteRoot)) {
        return const JsonResult({'error': 'Forbidden'}, status: 403);
      }

      final entity = File(fullPath);

      if (await FileSystemEntity.isDirectory(fullPath)) {
        if (!ctx.uri.path.endsWith('/')) {
          return RedirectResult('${ctx.uri.path}/');
        }

        final indexFile = File(p.join(fullPath, 'index.html'));
        if (await indexFile.exists()) {
          return _serveFile(ctx, indexFile);
        }

        return const TextResult('Directory Listing Forbidden', status: 403);
      }

      if (await entity.exists()) {
        return _serveFile(ctx, entity);
      }

      return const TextResult('File Not Found', status: 404);
    });
  }

  Future<Result> _serveFile(Context ctx, File file) async {
    final stat = await file.stat();
    final etag = '"${stat.changed.millisecondsSinceEpoch}-${stat.size}"';

    final clientEtag = ctx.headers.value(HttpHeaders.ifNoneMatchHeader);
    if (clientEtag == etag) {
      return const NotModifiedResult();
    }

    return FileResult(
      file,
    ).withHeader(HttpHeaders.etagHeader, etag).withHeader(HttpHeaders.cacheControlHeader, 'public, max-age=3600');
  }
}
