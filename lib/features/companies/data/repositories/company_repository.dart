import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../../core/network/network_exception.dart';
import '../datasource/remote/company_remote_datasource.dart';
import '../models/company_model.dart';

abstract class CompanyRepository {
  Future<PaginatedCompaniesResponse> getCompanies({
    String? page,
    String? limit,
    String? search,
    String? ownerId,
    String? departmentId,
    bool? ignorePermissions,
    String? lifecycleStage,
    String? leadStatus,
    String? createdDateRange,
    String? sort,
    String? order,
  });

  Future<CompanyModel> getCompanyById(String id);

  Future<CompanyModel> createCompany(Map<String, dynamic> companyData);

  Future<CompanyModel> updateCompany(String id, Map<String, dynamic> companyData);

  Future<bool> deleteCompany(String id, {String? departmentId});
}

class CompanyRepositoryImpl implements CompanyRepository {
  final CompanyRemoteDataSource _remoteDataSource;

  CompanyRepositoryImpl({CompanyRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? CompanyRemoteDataSourceImpl();

  @override
  Future<PaginatedCompaniesResponse> getCompanies({
    String? page,
    String? limit,
    String? search,
    String? ownerId,
    String? departmentId,
    bool? ignorePermissions,
    String? lifecycleStage,
    String? leadStatus,
    String? createdDateRange,
    String? sort,
    String? order,
  }) async {
    try {
      return await _remoteDataSource.getCompanies(
        page: page,
        limit: limit,
        search: search,
        ownerId: ownerId,
        departmentId: departmentId,
        ignorePermissions: ignorePermissions,
        lifecycleStage: lifecycleStage,
        leadStatus: leadStatus,
        createdDateRange: createdDateRange,
        sort: sort,
        order: order,
      );
    } catch (e) {
      debugPrint('[GET /api/companies ERROR]: $e');
      if (e is DioException) {
        throw NetworkException.fromDioException(e);
      }
      throw NetworkException(message: e.toString());
    }
  }

  @override
  Future<CompanyModel> getCompanyById(String id) async {
    try {
      return await _remoteDataSource.getCompanyById(id);
    } catch (e) {
      debugPrint('[GET /api/companies/$id ERROR]: $e');
      if (e is DioException) {
        throw NetworkException.fromDioException(e);
      }
      throw NetworkException(message: e.toString());
    }
  }

  @override
  Future<CompanyModel> createCompany(Map<String, dynamic> companyData) async {
    try {
      return await _remoteDataSource.createCompany(companyData);
    } catch (e) {
      debugPrint('[POST /api/companies ERROR]: $e');
      if (e is DioException) {
        throw NetworkException.fromDioException(e);
      }
      throw NetworkException(message: e.toString());
    }
  }

  @override
  Future<CompanyModel> updateCompany(String id, Map<String, dynamic> companyData) async {
    try {
      return await _remoteDataSource.updateCompany(id, companyData);
    } catch (e) {
      debugPrint('[PUT /api/companies/$id ERROR]: $e');
      if (e is DioException) {
        throw NetworkException.fromDioException(e);
      }
      throw NetworkException(message: e.toString());
    }
  }

  @override
  Future<bool> deleteCompany(String id, {String? departmentId}) async {
    try {
      return await _remoteDataSource.deleteCompany(id, departmentId: departmentId);
    } catch (e) {
      debugPrint('[DELETE /api/companies/$id ERROR]: $e');
      if (e is DioException) {
        throw NetworkException.fromDioException(e);
      }
      throw NetworkException(message: e.toString());
    }
  }
}
