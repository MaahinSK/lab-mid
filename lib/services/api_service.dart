import 'dart:io';
import 'package:dio/dio.dart';
import '../models/landmark.dart';
import '../utils/constants.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: Constants.baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  // Get all landmarks
  Future<List<Landmark>> getLandmarks() async {
    try {
      print('Fetching landmarks from: ${Constants.baseUrl}?action=get_landmarks&key=${Constants.apiKey}');

      final response = await _dio.get('', queryParameters: {
        'action': 'get_landmarks',
        'key': Constants.apiKey,
      });

      print('Response status: ${response.statusCode}');
      print('Response data type: ${response.data.runtimeType}');

      if (response.statusCode == 200) {
        if (response.data is List) {
          List<dynamic> data = response.data;
          print('Received ${data.length} landmarks');

          List<Landmark> landmarks = [];
          for (var json in data) {
            try {
              landmarks.add(Landmark.fromJson(json));
            } catch (e) {
              print('Error parsing landmark: $e');
              print('Problematic JSON: $json');
            }
          }

          return landmarks.where((landmark) => !landmark.isDeleted).toList();
        } else {
          print('Unexpected response format: ${response.data}');
          throw Exception('Invalid response format');
        }
      }
      throw Exception('Failed to load landmarks');
    } on DioException catch (e) {
      print('Dio error: ${e.message}');
      print('Response: ${e.response?.data}');
      throw Exception('Network error: ${e.message}');
    }
  }

  // Visit a landmark
  Future<Map<String, dynamic>> visitLandmark({
    required int landmarkId,
    required double userLat,
    required double userLon,
  }) async {
    try {
      final response = await _dio.post(
        '',
        queryParameters: {
          'action': 'visit_landmark',
          'key': Constants.apiKey,
        },
        data: {
          'landmark_id': landmarkId,
          'user_lat': userLat,
          'user_lon': userLon,
        },
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': response.data,
        };
      }
      return {
        'success': false,
        'message': 'Failed to visit landmark',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.message}',
      };
    }
  }

  // Create a new landmark
  Future<Map<String, dynamic>> createLandmark({
    required String title,
    required double lat,
    required double lon,
    required File imageFile,
  }) async {
    try {
      String fileName = imageFile.path.split('/').last;

      FormData formData = FormData.fromMap({
        'title': title,
        'lat': lat.toString(),
        'lon': lon.toString(),
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        '',
        queryParameters: {
          'action': 'create_landmark',
          'key': Constants.apiKey,
        },
        data: formData,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': response.data,
        };
      }
      return {
        'success': false,
        'message': 'Failed to create landmark',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.message}',
      };
    }
  }



  // Add this method to get deleted landmarks
  Future<List<Landmark>> getDeletedLandmarks() async {
    try {
      final response = await _dio.get('', queryParameters: {
        'action': 'get_landmarks',
        'key': Constants.apiKey,
        'include_deleted': '1', // Try this - might work
      });

      if (response.statusCode == 200) {
        List<dynamic> data = response.data;
        return data.map((json) => Landmark.fromJson(json))
            .where((landmark) => landmark.isDeleted)
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching deleted landmarks: $e');
      return [];
    }
  }

// Add restore method
  Future<bool> restoreLandmark(int id) async {
    try {
      FormData formData = FormData.fromMap({
        'id': id.toString(),
      });

      final response = await _dio.post(
        '',
        queryParameters: {
          'action': 'restore_landmark',
          'key': Constants.apiKey,
        },
        data: formData,
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }

  // Delete landmark (soft delete)
  Future<bool> deleteLandmark(int id) async {
    try {
      FormData formData = FormData.fromMap({
        'id': id.toString(),
      });

      final response = await _dio.post(
        '',
        queryParameters: {
          'action': 'delete_landmark',
          'key': Constants.apiKey,
        },
        data: formData,
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }
}