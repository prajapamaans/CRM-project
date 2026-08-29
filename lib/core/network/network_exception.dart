import 'package:dio/dio.dart';

/// Enterprise network exception class wrapping HTTP errors and connection failures.
class NetworkException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  const NetworkException({
    required this.message,
    this.statusCode,
    this.data,
  });

  factory NetworkException.fromDioException(DioException dioException) {
    switch (dioException.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        final errDetail = dioException.message ?? dioException.error?.toString();
        final detailMsg = errDetail != null && errDetail.isNotEmpty && !errDetail.contains('DioException')
            ? ' ($errDetail)'
            : '';
        return NetworkException(
          message: 'Connection failed. Please check your internet connection.$detailMsg',
        );
      case DioExceptionType.badResponse:
        final response = dioException.response;
        final statusCode = response?.statusCode;
        final responseData = response?.data;
        String? serverMessage;

        if (responseData is Map<String, dynamic>) {
          final errorsField = responseData['errors'] ?? responseData['details'];
          if (errorsField is List && errorsField.isNotEmpty) {
            serverMessage = errorsField.join(', ');
          } else if (responseData['message'] is List && (responseData['message'] as List).isNotEmpty) {
            serverMessage = (responseData['message'] as List).join(', ');
          } else if (errorsField != null && errorsField.toString().isNotEmpty) {
            serverMessage = errorsField.toString();
          } else if (responseData['message'] != null) {
            serverMessage = responseData['message'].toString();
          } else if (responseData['error'] != null) {
            serverMessage = responseData['error'].toString();
          }
        }

        switch (statusCode) {
          case 400:
            return NetworkException(
              message: serverMessage ?? 'Bad request.',
              statusCode: statusCode,
              data: responseData,
            );
          case 401:
          case 403:
            return NetworkException(
              message: serverMessage ?? 'Invalid email or password',
              statusCode: statusCode,
              data: responseData,
            );
          case 404:
            return NetworkException(
              message: serverMessage ?? 'Resource not found.',
              statusCode: statusCode,
              data: responseData,
            );
          case 422:
            return NetworkException(
              message: serverMessage ?? 'Validation error.',
              statusCode: statusCode,
              data: responseData,
            );
          case 500:
          default:
            return NetworkException(
              message: serverMessage ?? 'Server error occurred. Please try again later.',
              statusCode: statusCode,
              data: responseData,
            );
        }
      case DioExceptionType.cancel:
        return const NetworkException(message: 'Request was cancelled.');
      default:
        return const NetworkException(
          message: 'Unexpected network error occurred.',
        );
    }
  }

  @override
  String toString() => message;
}
