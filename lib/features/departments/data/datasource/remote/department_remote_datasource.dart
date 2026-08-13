import '../../../../../core/network/api_constants.dart';
import '../../../../../core/network/api_service.dart';
import '../../models/department_model.dart';

abstract class DepartmentRemoteDataSource {
  Future<List<DepartmentModel>> getDepartments({bool includeDeleted = true});
  Future<DepartmentModel> createDepartment(String name);
  Future<DepartmentModel> updateDepartment(String id, String name);
  Future<void> deleteDepartment(String id);
}

class DepartmentRemoteDataSourceImpl implements DepartmentRemoteDataSource {
  final ApiService _apiService;

  DepartmentRemoteDataSourceImpl({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  @override
  Future<List<DepartmentModel>> getDepartments({bool includeDeleted = true}) async {
    final response = await _apiService.get(
      ApiConstants.departments,
      queryParameters: {
        'includeDeleted': includeDeleted,
      },
    );

    final responseData = response.data;
    List<dynamic> listData = [];

    if (responseData is Map<String, dynamic> && responseData.containsKey('data')) {
      listData = responseData['data'] as List<dynamic>? ?? [];
    } else if (responseData is List<dynamic>) {
      listData = responseData;
    }

    return listData
        .map((item) => DepartmentModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<DepartmentModel> createDepartment(String name) async {
    final response = await _apiService.post(
      ApiConstants.departments,
      data: {'name': name},
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
        return DepartmentModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      return DepartmentModel.fromJson(data);
    }
    final autoSlug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    return DepartmentModel(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, slug: autoSlug);
  }

  @override
  Future<DepartmentModel> updateDepartment(String id, String name) async {
    final response = await _apiService.put(
      '${ApiConstants.departments}/$id',
      data: {'name': name},
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
        return DepartmentModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      return DepartmentModel.fromJson(data);
    }
    return DepartmentModel(id: id, name: name);
  }

  @override
  Future<void> deleteDepartment(String id) async {
    await _apiService.delete('${ApiConstants.departments}/$id');
  }
}
