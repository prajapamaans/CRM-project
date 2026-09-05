import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../../core/network/network_exception.dart';
import '../datasource/remote/contact_remote_datasource.dart';
import '../models/contact_model.dart';

abstract class ContactRepository {
  Future<PaginatedContactsResponse> getContacts({
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

  Future<ContactModel> getContactById(String id);

  Future<ContactModel> createContact(Map<String, dynamic> contactData);

  Future<ContactModel> updateContact(String id, Map<String, dynamic> contactData);

  Future<bool> deleteContact(String id, {String? departmentId});
}

class ContactRepositoryImpl implements ContactRepository {
  final ContactRemoteDataSource _remoteDataSource;

  ContactRepositoryImpl({ContactRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? ContactRemoteDataSourceImpl();

  @override
  Future<PaginatedContactsResponse> getContacts({
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
      return await _remoteDataSource.getContacts(
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
      debugPrint('[GET /api/contacts ERROR]: $e');
      if (e is DioException) {
        throw NetworkException.fromDioException(e);
      }
      throw NetworkException(message: e.toString());
    }
  }

  @override
  Future<ContactModel> getContactById(String id) async {
    try {
      return await _remoteDataSource.getContactById(id);
    } catch (e) {
      debugPrint('[GET /api/contacts/$id ERROR]: $e');
      if (e is DioException) {
        throw NetworkException.fromDioException(e);
      }
      throw NetworkException(message: e.toString());
    }
  }

  @override
  Future<ContactModel> createContact(Map<String, dynamic> contactData) async {
    try {
      return await _remoteDataSource.createContact(contactData);
    } catch (e) {
      debugPrint('[POST /api/contacts ERROR]: $e');
      if (e is DioException) {
        throw NetworkException.fromDioException(e);
      }
      throw NetworkException(message: e.toString());
    }
  }

  @override
  Future<ContactModel> updateContact(String id, Map<String, dynamic> contactData) async {
    try {
      return await _remoteDataSource.updateContact(id, contactData);
    } catch (e) {
      debugPrint('[PATCH /api/contacts/$id ERROR]: $e');
      if (e is DioException) {
        throw NetworkException.fromDioException(e);
      }
      throw NetworkException(message: e.toString());
    }
  }

  @override
  Future<bool> deleteContact(String id, {String? departmentId}) async {
    try {
      return await _remoteDataSource.deleteContact(id, departmentId: departmentId);
    } catch (e) {
      debugPrint('[DELETE /api/contacts/$id ERROR]: $e');
      if (e is DioException) {
        throw NetworkException.fromDioException(e);
      }
      throw NetworkException(message: e.toString());
    }
  }
}
