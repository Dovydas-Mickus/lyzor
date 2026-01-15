import 'package:lyzor/lyzor.dart';
import 'package:lyzor/src/lyzor_validator.dart';

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

Middleware validateBody(Validator validator) {
  return (ctx, next) async {
    try {
      final body = await ctx.json;

      final errors = validator.validate(body);

      if (errors.isNotEmpty) {
        return Results.json({'error': 'Validation Failed', 'details': errors}, status: 400);
      }

      return await next();
    } catch (e) {
      return Results.json({'error': 'Invalid JSON body'}, status: 400);
    }
  };
}

Middleware validateQuery(Validator validator) {
  return (ctx, next) async {
    final errors = validator.validate(ctx.queryParams);
    if (errors.isNotEmpty) {
      return Results.json({'error': 'Invalid query parameters', 'details': errors}, status: 400);
    }
    return await next();
  };
}
