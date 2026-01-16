import 'package:lyzor/lyzor.dart';
import 'package:lyzor/src/lyzor_validator.dart';

Middleware recovery() {
  return (ctx, next) async {
    try {
      return await next();
    } catch (e, st) {
      if (e is HttpException) {
        print('[HTTP ${e.statusCode}] ${ctx.method} ${ctx.uri.path} - ${e.message}');

        return Results.json({'error': e.message, if (e.details != null) 'details': e.details}, status: e.statusCode);
      }

      print('[Recovery] Unhandled Error: $e\n$st');

      return Results.json({'error': 'Internal Server Error'}, status: 500);
    }
  };
}

Middleware logger() {
  return (ctx, next) async {
    final sw = Stopwatch()..start();
    final out = await next();
    sw.stop();

    int status = (out is Result) ? out.status : ctx.response.statusCode;
    print('${ctx.method} ${ctx.uri.path} | $status | ${sw.elapsedMilliseconds}ms');

    return out;
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
