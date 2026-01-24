import 'dart:io';

class HttpException implements Exception {
  final String message;
  final int statusCode;
  final Map<String, dynamic>? details;

  HttpException(this.message, this.statusCode, {this.details});

  @override
  String toString() => 'HttpException: $statusCode - $message';

  factory HttpException.fromCode(int statusCode, [String? message]) {
    switch (statusCode) {
      // 4xx Client Errors
      case HttpStatus.badRequest:
        return BadRequestException(message ?? 'Bad Request');
      case HttpStatus.unauthorized:
        return UnauthorizedException(message ?? 'Unauthorized');
      case HttpStatus.paymentRequired:
        return PaymentRequiredException(message ?? 'Payment Required');
      case HttpStatus.forbidden:
        return ForbiddenException(message ?? 'Forbidden');
      case HttpStatus.notFound:
        return NotFoundException(message ?? 'Not Found');
      case HttpStatus.methodNotAllowed:
        return MethodNotAllowedException.generic(message ?? 'Method Not Allowed');
      case HttpStatus.notAcceptable:
        return NotAcceptableException(message ?? 'Not Acceptable');
      case HttpStatus.proxyAuthenticationRequired:
        return ProxyAuthenticationRequiredException(message ?? 'Proxy Authentication Required');
      case HttpStatus.requestTimeout:
        return RequestTimeoutException(message ?? 'Request Timeout');
      case HttpStatus.conflict:
        return ConflictException(message ?? 'Conflict');
      case HttpStatus.gone:
        return GoneException(message ?? 'Gone');
      case HttpStatus.lengthRequired:
        return LengthRequiredException(message ?? 'Length Required');
      case HttpStatus.preconditionFailed:
        return PreconditionFailedException(message ?? 'Precondition Failed');
      case HttpStatus.requestEntityTooLarge:
        return ContentTooLargeException(message ?? 'Content Too Large');
      case HttpStatus.requestUriTooLong:
        return UriTooLongException(message ?? 'URI Too Long');
      case HttpStatus.unsupportedMediaType:
        return UnsupportedMediaTypeException(message ?? 'Unsupported Media Type');
      case HttpStatus.requestedRangeNotSatisfiable:
        return RangeNotSatisfiableException(message ?? 'Requested Range Not Satisfiable');
      case HttpStatus.expectationFailed:
        return ExpectationFailedException(message ?? 'Expectation Failed');
      case HttpStatus.unprocessableEntity:
        return UnprocessableContentException(message ?? 'Unprocessable Content');
      case HttpStatus.locked:
        return LockedException(message ?? 'Locked');
      case HttpStatus.failedDependency:
        return FailedDependencyException(message ?? 'Failed Dependency');
      case HttpStatus.upgradeRequired:
        return UpgradeRequiredException(message ?? 'Upgrade Required');
      case HttpStatus.preconditionRequired:
        return PreconditionRequiredException(message ?? 'Precondition Required');
      case HttpStatus.tooManyRequests:
        return TooManyRequestsException(message ?? 'Too Many Requests');
      case HttpStatus.requestHeaderFieldsTooLarge:
        return RequestHeaderFieldsTooLargeException(message ?? 'Request Header Fields Too Large');
      case HttpStatus.unavailableForLegalReasons:
        return UnavailableForLegalReasonsException(message ?? 'Unavailable For Legal Reasons');

      // 5xx Server Errors
      case HttpStatus.internalServerError:
        return InternalServerErrorException(message ?? 'Internal Server Error');
      case HttpStatus.notImplemented:
        return NotImplementedException(message ?? 'Not Implemented');
      case HttpStatus.badGateway:
        return BadGatewayException(message ?? 'Bad Gateway');
      case HttpStatus.serviceUnavailable:
        return ServiceUnavailableException(message ?? 'Service Unavailable');
      case HttpStatus.gatewayTimeout:
        return GatewayTimeoutException(message ?? 'Gateway Timeout');
      case HttpStatus.httpVersionNotSupported:
        return HttpVersionNotSupportedException(message ?? 'HTTP Version Not Supported');
      case HttpStatus.insufficientStorage:
        return InsufficientStorageException(message ?? 'Insufficient Storage');
      case HttpStatus.loopDetected:
        return LoopDetectedException(message ?? 'Loop Detected');
      case HttpStatus.networkAuthenticationRequired:
        return NetworkAuthenticationRequiredException(message ?? 'Network Authentication Required');

      // Default fallback
      default:
        return HttpException(message ?? 'HTTP Error', statusCode);
    }
  }
}

// --- 4xx Client Errors ---

class BadRequestException extends HttpException {
  BadRequestException([String message = 'Bad Request']) : super(message, HttpStatus.badRequest);
}

class UnauthorizedException extends HttpException {
  UnauthorizedException([String message = 'Unauthorized']) : super(message, HttpStatus.unauthorized);
}

class PaymentRequiredException extends HttpException {
  PaymentRequiredException([String message = 'Payment Required']) : super(message, HttpStatus.paymentRequired);
}

class ForbiddenException extends HttpException {
  ForbiddenException([String message = 'Forbidden']) : super(message, HttpStatus.forbidden);
}

class NotFoundException extends HttpException {
  NotFoundException([String message = 'Not Found']) : super(message, HttpStatus.notFound);
}

class MethodNotAllowedException extends HttpException {
  final Set<String>? allowedMethods;

  MethodNotAllowedException(String method, String path, {this.allowedMethods, String? message})
    : super(
        message ?? 'Method $method not allowed for $path',
        HttpStatus.methodNotAllowed,
        details: allowedMethods != null ? {'allowed': allowedMethods.toList()} : null,
      );

  // Generic constructor for the factory
  MethodNotAllowedException.generic([String message = 'Method Not Allowed'])
    : allowedMethods = null,
      super(message, HttpStatus.methodNotAllowed);
}

class NotAcceptableException extends HttpException {
  NotAcceptableException([String message = 'Not Acceptable']) : super(message, HttpStatus.notAcceptable);
}

class ProxyAuthenticationRequiredException extends HttpException {
  ProxyAuthenticationRequiredException([String message = 'Proxy Authentication Required'])
    : super(message, HttpStatus.proxyAuthenticationRequired);
}

class RequestTimeoutException extends HttpException {
  RequestTimeoutException([String message = 'Request Timeout']) : super(message, HttpStatus.requestTimeout);
}

class ConflictException extends HttpException {
  ConflictException([String message = 'Conflict']) : super(message, HttpStatus.conflict);
}

class GoneException extends HttpException {
  GoneException([String message = 'Gone']) : super(message, HttpStatus.gone);
}

class LengthRequiredException extends HttpException {
  LengthRequiredException([String message = 'Length Required']) : super(message, HttpStatus.lengthRequired);
}

class PreconditionFailedException extends HttpException {
  PreconditionFailedException([String message = 'Precondition Failed']) : super(message, HttpStatus.preconditionFailed);
}

class ContentTooLargeException extends HttpException {
  ContentTooLargeException([String message = 'Content Too Large']) : super(message, HttpStatus.requestEntityTooLarge);
}

class UriTooLongException extends HttpException {
  UriTooLongException([String message = 'URI Too Long']) : super(message, HttpStatus.requestUriTooLong);
}

class UnsupportedMediaTypeException extends HttpException {
  UnsupportedMediaTypeException([String message = 'Unsupported Media Type'])
    : super(message, HttpStatus.unsupportedMediaType);
}

class RangeNotSatisfiableException extends HttpException {
  RangeNotSatisfiableException([String message = 'Requested Range Not Satisfiable'])
    : super(message, HttpStatus.requestedRangeNotSatisfiable);
}

class ExpectationFailedException extends HttpException {
  ExpectationFailedException([String message = 'Expectation Failed']) : super(message, HttpStatus.expectationFailed);
}

class UnprocessableContentException extends HttpException {
  UnprocessableContentException([String message = 'Unprocessable Content'])
    : super(message, HttpStatus.unprocessableEntity);
}

class LockedException extends HttpException {
  LockedException([String message = 'Locked']) : super(message, HttpStatus.locked);
}

class FailedDependencyException extends HttpException {
  FailedDependencyException([String message = 'Failed Dependency']) : super(message, HttpStatus.failedDependency);
}

class UpgradeRequiredException extends HttpException {
  UpgradeRequiredException([String message = 'Upgrade Required']) : super(message, HttpStatus.upgradeRequired);
}

class PreconditionRequiredException extends HttpException {
  PreconditionRequiredException([String message = 'Precondition Required'])
    : super(message, HttpStatus.preconditionRequired);
}

class TooManyRequestsException extends HttpException {
  TooManyRequestsException([String message = 'Too Many Requests']) : super(message, HttpStatus.tooManyRequests);
}

class RequestHeaderFieldsTooLargeException extends HttpException {
  RequestHeaderFieldsTooLargeException([String message = 'Request Header Fields Too Large'])
    : super(message, HttpStatus.requestHeaderFieldsTooLarge);
}

class UnavailableForLegalReasonsException extends HttpException {
  UnavailableForLegalReasonsException([String message = 'Unavailable For Legal Reasons'])
    : super(message, HttpStatus.unavailableForLegalReasons);
}

// --- 5xx Server Errors ---

class InternalServerErrorException extends HttpException {
  InternalServerErrorException([String message = 'Internal Server Error'])
    : super(message, HttpStatus.internalServerError);
}

class NotImplementedException extends HttpException {
  NotImplementedException([String message = 'Not Implemented']) : super(message, HttpStatus.notImplemented);
}

class BadGatewayException extends HttpException {
  BadGatewayException([String message = 'Bad Gateway']) : super(message, HttpStatus.badGateway);
}

class ServiceUnavailableException extends HttpException {
  ServiceUnavailableException([String message = 'Service Unavailable']) : super(message, HttpStatus.serviceUnavailable);
}

class GatewayTimeoutException extends HttpException {
  GatewayTimeoutException([String message = 'Gateway Timeout']) : super(message, HttpStatus.gatewayTimeout);
}

class HttpVersionNotSupportedException extends HttpException {
  HttpVersionNotSupportedException([String message = 'HTTP Version Not Supported'])
    : super(message, HttpStatus.httpVersionNotSupported);
}

class InsufficientStorageException extends HttpException {
  InsufficientStorageException([String message = 'Insufficient Storage'])
    : super(message, HttpStatus.insufficientStorage);
}

class LoopDetectedException extends HttpException {
  LoopDetectedException([String message = 'Loop Detected']) : super(message, HttpStatus.loopDetected);
}

class NetworkAuthenticationRequiredException extends HttpException {
  NetworkAuthenticationRequiredException([String message = 'Network Authentication Required'])
    : super(message, HttpStatus.networkAuthenticationRequired);
}
