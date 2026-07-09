import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../uploads/cloudinary_service.dart';
import '../../../uploads/image_upload.dart';

/// Receipt attachment: pick (camera/gallery) → compress → upload to
/// Cloudinary with inline progress, with replace/remove and tap-to-retry on
/// failure. Only the secure Cloudinary URL is ever stored — Firebase Storage
/// is never used.
class ReceiptPicker extends StatefulWidget {
  final String userId;
  final String initialUrl;
  final ValueChanged<String> onChanged;

  const ReceiptPicker({
    super.key,
    required this.userId,
    required this.onChanged,
    this.initialUrl = '',
  });

  @override
  State<ReceiptPicker> createState() => _ReceiptPickerState();
}

class _ReceiptPickerState extends State<ReceiptPicker> {
  late String _url = widget.initialUrl;
  File? _pendingFile;
  bool _uploading = false;
  double _progress = 0;
  String? _error;

  Future<void> _pick() async {
    final file = await pickImage(context);
    if (file == null || !mounted) return;
    setState(() {
      _pendingFile = file;
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
        folder: 'securebank/receipts/${widget.userId}',
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() {
        _url = result.url;
        _uploading = false;
        _pendingFile = null;
      });
      widget.onChanged(result.url);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = mapError(e).message;
      });
    }
  }

  void _remove() {
    setState(() {
      _url = '';
      _pendingFile = null;
      _error = null;
    });
    widget.onChanged('');
  }

  void _preview() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: _pendingFile != null
              ? Image.file(_pendingFile!)
              : Image.network(_url),
        ),
      ),
    );
  }

  bool get _hasImage => _url.isNotEmpty || _pendingFile != null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasError = _error != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Receipt (optional)',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          child: Stack(
            children: [
              GestureDetector(
                onTap: _hasImage ? _preview : (_uploading ? null : _pick),
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(AppTokens.radius),
                    border: Border.all(
                      color: hasError
                          ? AppTokens.danger
                          : scheme.outlineVariant.withValues(alpha: 0.6),
                      width: hasError ? 1.6 : 1,
                    ),
                  ),
                  child: _hasImage
                      ? Image(
                          image: _pendingFile != null
                              ? FileImage(_pendingFile!) as ImageProvider
                              : NetworkImage(_url),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 140,
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_outlined,
                                  color: scheme.onSurfaceVariant, size: 28),
                              const SizedBox(height: 6),
                              Text('Tap to attach a receipt',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                ),
              ),
              if (_uploading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.45),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              value: _progress > 0 ? _progress : null,
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('${(_progress * 100).round()}%',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              if (hasError && !_uploading)
                Positioned.fill(
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: InkWell(
                      onTap: _upload,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh, color: Colors.white, size: 26),
                            SizedBox(height: 4),
                            Text('Upload failed — tap to retry',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (_hasImage && !_uploading)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Row(
                    children: [
                      _iconAction(Icons.edit_outlined, _pick),
                      const SizedBox(width: 6),
                      _iconAction(Icons.delete_outline, _remove),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _iconAction(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      ),
    );
  }
}
