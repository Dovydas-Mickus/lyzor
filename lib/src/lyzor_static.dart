import 'dart:convert' show HtmlEscape;
import 'dart:io';

import 'package:lyzor/lyzor.dart';
import 'package:path/path.dart' as p;

const _htmlEscape = HtmlEscape();

extension LyzorStatic on Lyzor {
  void static(
    String routePath,
    String fileSystemPath, {
    bool listDirectories = false,
    String cacheControl = 'public, max-age=3600',
  }) {
    final absoluteRoot = p.canonicalize(Directory(fileSystemPath).absolute.path);

    final prefix = routePath.endsWith('/') ? routePath.substring(0, routePath.length - 1) : routePath;

    route('$prefix/*').get(() async {
      final ctx = Context.current;

      final subPath = ctx.pathParams['*'] ?? '';

      final fullPath = p.canonicalize(p.join(absoluteRoot, subPath));

      if (!fullPath.startsWith(absoluteRoot + p.separator) && fullPath != absoluteRoot) {
        return const JsonResult({'error': 'Forbidden'}, status: 403);
      }

      if (await FileSystemEntity.isDirectory(fullPath)) {
        if (!ctx.uri.path.endsWith('/')) {
          return RedirectResult('${ctx.uri.path}/');
        }

        final indexFile = File(p.join(fullPath, 'index.html'));
        if (await indexFile.exists()) {
          return _serveFile(ctx, indexFile, cacheControl);
        }

        if (!listDirectories) {
          return const TextResult('Directory Listing Forbidden', status: 403);
        }

        return _listDirectory(fullPath, ctx.uri.path);
      }

      final entity = File(fullPath);

      if (await entity.exists()) {
        return _serveFile(ctx, entity, cacheControl);
      }

      return const TextResult('File Not Found', status: 404);
    });
  }

  Future<Result> _serveFile(Context ctx, File file, String cacheControl) async {
    final stat = await file.stat();
    final etag = '"${stat.changed.millisecondsSinceEpoch}-${stat.size}"';

    final clientEtag = ctx.headers.value(HttpHeaders.ifNoneMatchHeader);
    if (clientEtag == etag) {
      return const NotModifiedResult();
    }

    return FileResult(file)
        .withHeader(HttpHeaders.etagHeader, etag)
        .withHeader(HttpHeaders.cacheControlHeader, cacheControl);
  }

  Future<Result> _listDirectory(String dirPath, String uriPath) async {
    final entities = await Directory(dirPath).list().toList()
      ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

    final sb = StringBuffer()
      ..write('<!DOCTYPE html><html><body>')
      ..write('<h1>Index of ${_htmlEscape.convert(uriPath)}</h1><ul>');

    if (uriPath != '/') {
      sb.write('<li><a href="../">../</a></li>');
    }

    for (final entity in entities) {
      final name = p.basename(entity.path);
      final isDir = entity is Directory;
      final href = Uri.encodeComponent(name);
      final display = _htmlEscape.convert(name);
      sb.write('<li><a href="$href${isDir ? '/' : ''}">$display${isDir ? '/' : ''}</a></li>');
    }

    sb.write('</ul></body></html>');
    return HtmlResult(sb.toString());
  }
}
