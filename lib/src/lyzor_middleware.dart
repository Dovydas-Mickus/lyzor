import 'package:lyzor/lyzor.dart';

Middleware recovery() {
  return (ctx, next) async {
    try {
      return await next();
    } catch (e, st) {
      print('[Recovery] Caught Exception: $e');
      print(st);

      return Results.json({'error': 'Internal Server Error', 'message': e.toString()}, status: 500);
    }
  };
}

Middleware logger() {
  return (ctx, next) async {
    final sw = Stopwatch()..start();
    final method = ctx.method;
    final path = ctx.uri.path;

    print('--> $method $path');

    final result = await next();

    sw.stop();
    final status = ctx.response.statusCode;

    print('<-- $method $path | $status | ${sw.elapsedMilliseconds}ms');

    return result;
  };
}
