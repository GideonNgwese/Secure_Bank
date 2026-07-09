import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/errors/app_exception.dart';
import 'cloudinary_service.dart';

/// Shows a camera/gallery chooser and returns the picked image, already
/// down-scaled + compressed (via image_picker's maxWidth/imageQuality) to keep
/// uploads small.
Future<File?> pickImage(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  final picked = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 80,
  );
  return picked == null ? null : File(picked.path);
}

/// Picks an image then uploads it to Cloudinary, showing a progress dialog.
/// Returns the upload (secure URL + public id) or null if cancelled/failed.
Future<CloudinaryUpload?> pickAndUpload(
  BuildContext context, {
  required String folder,
}) async {
  final file = await pickImage(context);
  if (file == null || !context.mounted) return null;
  return uploadWithProgress(context, file, folder: folder);
}

Future<CloudinaryUpload?> uploadWithProgress(
  BuildContext context,
  File file, {
  required String folder,
}) async {
  final progress = ValueNotifier<double>(0);
  final messenger = ScaffoldMessenger.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UploadProgressDialog(progress: progress),
  );
  try {
    final result = await CloudinaryService().uploadImage(
      file,
      folder: folder,
      onProgress: (p) => progress.value = p,
    );
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    return result;
  } catch (e) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    messenger.showSnackBar(SnackBar(content: Text(mapError(e).message)));
    return null;
  } finally {
    progress.dispose();
  }
}

class _UploadProgressDialog extends StatelessWidget {
  final ValueNotifier<double> progress;
  const _UploadProgressDialog({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (_, v, __) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 56,
                    width: 56,
                    child: CircularProgressIndicator(value: v > 0 ? v : null),
                  ),
                  const SizedBox(height: 14),
                  Text('${(v * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text('Uploading…'),
          ],
        ),
      ),
    );
  }
}
