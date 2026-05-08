import 'dart:io';
import 'package:lyzor/src/lyzor_base.dart';
import 'package:lyzor/src/lyzor_exceptions.dart';
import 'package:lyzor/src/lyzor_middleware.dart';
import 'package:lyzor/src/lyzor_response.dart';
import 'package:lyzor/src/lyzor_result.dart';

class BaseHelper {
  static Future<void> handleError(
    Response response,
    Object error,
    StackTrace st,
    String method,
    String path,
  ) async {
    JsonResult result;

    if (error is MethodNotAllowedException) {
      result = JsonResult(
        {'error': error.message, 'details': error.details},
        status: HttpStatus.methodNotAllowed,
        headers: {'Allow': error.allowedMethods?.join(', ') ?? ''},
      );
    } else if (error is HttpException) {
      result = JsonResult({'error': error.message, 'details': error.details}, status: error.statusCode);
    } else {
      print('[$method $path] Unhandled Error: $error\n$st');
      result = JsonResult({'error': 'Internal Server Error'}, status: 500);
    }

    await result.execute(response);
  }

  static Future<Object?> executePipeline(Context ctx, List<Middleware> pipeline, [int index = 0]) async {
    if (index >= pipeline.length) return null;

    return coerce(await pipeline[index](ctx, () => executePipeline(ctx, pipeline, index + 1)));
  }

  static Result? coerce(Object? v) {
    if (v == null) return null;
    if (v is Result) return v;

    if (v is Map || v is List) return JsonResult(v);
    if (v is String) return TextResult(v);

    return TextResult(v.toString());
  }
}
