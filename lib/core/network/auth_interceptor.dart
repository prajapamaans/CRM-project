import 'package:dio/dio.dart';
import '../storage/secure_storage_service.dart';

/// Interceptor that automatically attaches Authorization Bearer token and active departmentId to authenticated HTTP requests.
class AuthInterceptor extends Interceptor {
  final SecureStorageService _storageService;
  final String Function()? _departmentIdProvider;

  AuthInterceptor({
    SecureStorageService? storageService,
    String Function()? departmentIdProvider,
  })  : _storageService = storageService ?? SecureStorageService(),
        _departmentIdProvider = departmentIdProvider;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storageService.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    final hasDeptHeader = options.headers.containsKey('X-Department-Id') ||
        options.headers.containsKey('departmentId') ||
        options.headers.containsKey('department_id');

    if (!hasDeptHeader) {
      final activeDeptId = _departmentIdProvider?.call() ??
          await _storageService.getSelectedDepartmentId();

      if (activeDeptId != null && activeDeptId.isNotEmpty) {
        options.headers['departmentId'] = activeDeptId;
        options.headers['department_id'] = activeDeptId;
        options.headers['X-Department-Id'] = activeDeptId;
      }
    } else if (options.headers['X-Department-Id'] == 'none' || options.headers['X-Department-Id'] == 'all') {
      options.headers.remove('X-Department-Id');
      options.headers.remove('departmentId');
      options.headers.remove('department_id');
    }

    super.onRequest(options, handler);
  }
}
