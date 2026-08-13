import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../../core/network/network_exception.dart';
import '../datasource/remote/department_remote_datasource.dart';
import '../models/department_model.dart';

abstract class DepartmentRepository {
  Future<List<DepartmentModel>> getDepartments({bool includeDeleted = true});
  Future<DepartmentModel> createDepartment(String name);
  Future<DepartmentModel> updateDepartment(String id, String name);
  Future<void> deleteDepartment(String id);
}

class DepartmentRepositoryImpl implements DepartmentRepository {
  final DepartmentRemoteDataSource _remoteDataSource;

  DepartmentRepositoryImpl({DepartmentRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? DepartmentRemoteDataSourceImpl();

  @override
  Future<List<DepartmentModel>> getDepartments({bool includeDeleted = true}) async {
    try {
      final departments = await _remoteDataSource.getDepartments(includeDeleted: includeDeleted);

      debugPrint('==================================================');
      debugPrint('[GET /api/departments SUCCESS] Count: ${departments.length}');
      for (int i = 0; i < departments.length; i++) {
        debugPrint('[DEPARTMENT #$i] ${jsonEncode(departments[i].toJson())}');
      }
      debugPrint('==================================================');

      return departments;
    } on NetworkException catch (e) {
      debugPrint('[GET /api/departments ERROR] NetworkException: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[GET /api/departments ERROR] Unexpected error: $e');
      rethrow;
    }
  }

  @override
  Future<DepartmentModel> createDepartment(String name) async {
    try {
      return await _remoteDataSource.createDepartment(name);
    } catch (e) {
      debugPrint('[POST /api/departments ERROR]: $e');
      final autoSlug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
      return DepartmentModel(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, slug: autoSlug);
    }
  }

  @override
  Future<DepartmentModel> updateDepartment(String id, String name) async {
    try {
      return await _remoteDataSource.updateDepartment(id, name);
    } catch (e) {
      debugPrint('[PUT /api/departments/$id ERROR]: $e');
      return DepartmentModel(id: id, name: name);
    }
  }

  @override
  Future<void> deleteDepartment(String id) async {
    try {
      await _remoteDataSource.deleteDepartment(id);
    } catch (e) {
      debugPrint('[DELETE /api/departments/$id ERROR]: $e');
    }
  }
}
