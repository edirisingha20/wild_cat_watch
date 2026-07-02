import 'package:dio/dio.dart';

import '../features/profile/models/lookup_option.dart';
import 'api_service.dart';

class OrganizationService {
  OrganizationService({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  Future<List<LookupOption>> getDepartments() async {
    final Response<dynamic> response = await _apiService.get('users/departments/');
    final List<dynamic> data = response.data as List<dynamic>;
    return data
        .map((dynamic item) => LookupOption.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<List<LookupOption>> getPositions(int departmentId) async {
    final Response<dynamic> response = await _apiService.get(
      'users/positions/',
      queryParameters: <String, dynamic>{
        'department_id': departmentId,
      },
    );
    final List<dynamic> data = response.data as List<dynamic>;
    return data
        .map((dynamic item) => LookupOption.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
