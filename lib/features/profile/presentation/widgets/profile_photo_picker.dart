import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../uploads/cloudinary_service.dart';
import '../../../uploads/image_upload.dart';

/// Circular profile photo picker: pick (camera or gallery, future-ready) →
/// crop to a square → compress → upload to Cloudinary with an in-avatar
/// progress ring, and a tap-to-retry affordance if the upload fails.
///
/// Firebase Storage is never used — only the returned secure Cloudinary URL
/// is handed back via [onUploaded], for the parent to store in the draft.
class ProfilePhotoPicker extends StatefulWidget {
  final String userId;
  final String initialUrl;
  final ValueChanged<String> onUploaded;
  final double size;

  const ProfilePhotoPicker({
    super.key,
    required this.userId,
    required this.onUploaded,
    this.initialUrl = '',
    this.size = 112,
  });

  @override
  State<ProfilePhotoPicker> createState() => _ProfilePhotoPickerState();
}

class _ProfilePhotoPickerState extends State<ProfilePhotoPicker> {
  late String _uploadedUrl = widget.initialUrl;
  File? _pendingFile; // cropped file, kept around so "retry" can re-upload it
  bool _uploading = false;
  double _progress = 0;
  String? _error;

  Future<void> _pickAndCrop() async {
    final file = await pickImage(context);
    if (file == null || !mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: file.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      maxWidth: 800,
      maxHeight: 800,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop photo',
          toolbarColor: AppTokens.brand,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppTokens.brand,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          cropStyle: CropStyle.circle,
        ),
        IOSUiSettings(
          title: 'Crop photo',
          aspectRatioLockEnabled: true,
          cropStyle: CropStyle.circle,
        ),
      ],
    );
    if (cropped == null || !mounted) return;

    setState(() {
      _pendingFile = File(cropped.path);
      _error = null;
    });
    await _upload();
  }

  Future<void> _upload() async {
    final file = _pendingFile;
    if (file == null) return;
    setState(() {
      _uploading = true;
      _progress = 0;
      _error = null;
    });
    try {
      final result = await CloudinaryService().uploadImage(
        file,
        folder: 'securebank/profiles/${widget.userId}',
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() {
        _uploadedUrl = result.url;
        _uploading = false;
        _pendingFile = null;
      });
      widget.onUploaded(result.url);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = mapError(e).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasError = _error != null;

    return Column(
      children: [
        GestureDetector(
          onTap: _uploading
              ? null
              : (hasError && _pendingFile != null ? _upload : _pickAndCrop),
          child: SizedBox(
            width: widget.size + 14,
            height: widget.size + 14,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_uploading)
                  SizedBox(
                    width: widget.size + 14,
                    height: widget.size + 14,
                    child: CircularProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      strokeWidth: 3,
                      color: AppTokens.brand,
                      backgroundColor:
                          scheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: hasError
                        ? Border.all(color: AppTokens.danger, width: 2)
                        : null,
                    gradient: _uploadedUrl.isEmpty && _pendingFile == null
                        ? const LinearGradient(
                            colors: [AppTokens.brand, AppTokens.accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    image: _pendingFile != null
                        ? DecorationImage(
                            image: FileImage(_pendingFile!), fit: BoxFit.cover)
                        : (_uploadedUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(_uploadedUrl),
                                fit: BoxFit.cover)
                            : null),
                  ),
                  child: (_uploadedUrl.isEmpty && _pendingFile == null)
                      ? const Icon(Icons.person, color: Colors.white, size: 44)
                      : null,
                ),
                if (hasError)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: AppTokens.danger, shape: BoxShape.circle),
                      child: const Icon(Icons.refresh,
                          color: Colors.white, size: 16),
                    ),
                  )
                else
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTokens.brand,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 2.5),
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 15),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hasError
              ? 'Upload failed — tap to retry'
              : (_uploading
                  ? 'Uploading… ${(_progress * 100).round()}%'
                  : 'Profile photo (optional)'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: hasError ? FontWeight.w600 : FontWeight.normal,
            color: hasError ? AppTokens.danger : scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
