import 'package:dio/dio.dart';

class ApiService {
  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'http://10.0.2.2:8000/api/',
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  static final ApiService _instance = ApiService._internal();

  factory ApiService() => _instance;

  late final Dio _dio;

  Dio get dio => _dio;
}
