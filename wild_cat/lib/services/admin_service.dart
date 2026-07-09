import 'package:dio/dio.dart';

import '../features/admin/models/admin_user.dart';
import 'api_service.dart';

/// Admin-only backend operations. The endpoints reject non-admin users,
/// so callers should only reach this service when the profile role is admin.
class AdminService {
  final ApiService _api = ApiService();

  Future<List<AdminUser>> fetchUsers() async {
    final Response<dynamic> response = await _api.get('users/admin/users/');
    final List<dynamic> data = response.data as List<dynamic>;
    return data
        .map(
          (dynamic json) =>
              AdminUser.fromJson(Map<String, dynamic>.from(json as Map)),
        )
        .toList();
  }

  Future<AdminUser> updateUser(
    int userId, {
    String? fullName,
    String? role,
    bool? isActive,
  }) async {
    final Response<dynamic> response = await _api.patch(
      'users/admin/users/$userId/',
      data: <String, dynamic>{
        'full_name': ?fullName,
        'role': ?role,
        'is_active': ?isActive,
      },
    );
    return AdminUser.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<void> deleteUser(int userId) async {
    await _api.delete('users/admin/users/$userId/');
  }

  Future<void> deleteSighting(int sightingId) async {
    await _api.delete('sightings/$sightingId/');
  }
}
