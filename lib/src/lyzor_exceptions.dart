import 'dart:io';

class HttpException implements Exception {
  final String message;
  final int statusCode;
  final Map<String, dynamic>? details;

  HttpException(this.message, this.statusCode, {this.details});

  @override
  String toString() => 'HttpException: $statusCode - $message';
}

class NotFoundException extends HttpException {
  NotFoundException([String message = 'Not Found']) : super(message, HttpStatus.notFound);
}

class BadRequestException extends HttpException {
  BadRequestException([String message = 'Bad Request']) : super(message, HttpStatus.badRequest);
}

class UnauthorizedException extends HttpException {
  UnauthorizedException([String message = 'Unauthorized']) : super(message, HttpStatus.unauthorized);
}

class MethodNotAllowedException extends HttpException {
  final Set<String> allowedMethods;

  MethodNotAllowedException(String method, String path, this.allowedMethods, {String? message})
    : super(
        message ?? 'Method $method not allowed for $path',
        HttpStatus.methodNotAllowed,
        details: {'allowed': allowedMethods.toList()},
      );
}
