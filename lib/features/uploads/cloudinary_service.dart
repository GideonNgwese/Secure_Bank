import 'dart:io';
import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';

/// Result of a successful upload.
class CloudinaryUpload {
  final String url; // secure https URL to store in Firestore
  final String publicId; // used for deletion via the backend
  const CloudinaryUpload({required this.url, required this.publicId});
}

/// Reusable Cloudinary upload service — used for profile photos, KYC documents,
/// receipts, etc. No file is ever stored in Firebase Storage; only the returned
/// secure URL is saved to Firestore.
///
/// Uploads are **unsigned** (client-direct, using a public cloud name + upload
/// preset — no secret in the app). Deletion needs the API secret, so it is
/// proxied through the secure backend.
class CloudinaryService {
  final Dio _dio;
  CloudinaryService([Dio? dio]) : _dio = dio ?? Dio();

  bool get isConfigured => AppConfig.hasCloudinary;

  /// Uploads an image with progress (0..1), retrying transient failures.
  Future<CloudinaryUpload> uploadImage(
    File file, {
    required String folder,
    void Function(double progress)? onProgress,
    int retries = 2,
  }) async {
    if (!AppConfig.hasCloudinary) {
      throw const ServerException(
          'Image uploads are not configured yet. Add your Cloudinary details.');
    }
    final uri =
        'https://api.cloudinary.com/v1_1/${AppConfig.cloudinaryCloudName}/image/upload';

    DioException? lastError;
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final form = FormData.fromMap({
          'file': await MultipartFile.fromFile(file.path),
          'upload_preset': AppConfig.cloudinaryUploadPreset,
          'folder': folder,
        });
        final res = await _dio.post(
          uri,
          data: form,
          options: Options(sendTimeout: const Duration(seconds: 60),
              receiveTimeout: const Duration(seconds: 60)),
          onSendProgress: (sent, total) {
            if (total > 0) onProgress?.call(sent / total);
          },
        );
        final data = res.data as Map;
        return CloudinaryUpload(
          url: data['secure_url'] as String,
          publicId: data['public_id'] as String,
        );
      } on DioException catch (e) {
        lastError = e;
        // Don't retry client errors (bad preset, unauthorized, too large).
        final status = e.response?.statusCode ?? 0;
        if (status >= 400 && status < 500) break;
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    throw _mapDio(lastError!);
  }

  /// Deletes a previously uploaded asset. Requires the backend (Cloudinary API
  /// secret must never live in the app).
  Future<void> deleteImage(String publicId) async {
    if (!AppConfig.hasApi) {
      throw const ServerException(
          'Deleting uploads requires the secure backend.');
    }
    try {
      await _dio.post('${AppConfig.apiBaseUrl}/cloudinary/delete',
          data: {'publicId': publicId});
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  AppException _mapDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionTimeout:
        return const NetworkException('The upload timed out. Please try again.');
      default:
        final msg = e.response?.data is Map
            ? (e.response?.data['error']?['message'] ?? '').toString()
            : '';
        return ServerException(
            msg.isNotEmpty ? msg : 'Upload failed. Please try again.');
    }
  }
}
