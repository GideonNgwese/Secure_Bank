import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/premium_header.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/data/kyc_providers.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../models/user_model.dart';
import '../../models/kyc_model.dart';
import '../../features/uploads/cloudinary_service.dart';
import '../../features/uploads/image_upload.dart';
import '../../utils/constants.dart';

/// Customer Profile & KYC screen (guide section 5.2 "Profile/KYC page").
///
/// Shows the user's profile and identity-verification (KYC) status, and lets
/// them submit ID details for admin review. Because this academic prototype
/// does not store real document files, the user submits the document TYPE and
/// a reference/number — the admin then approves or rejects it.
class ProfileKycScreen extends ConsumerStatefulWidget {
  final String userId;
  const ProfileKycScreen({super.key, required this.userId});

  @override
  ConsumerState<ProfileKycScreen> createState() => _ProfileKycScreenState();
}

class _ProfileKycScreenState extends ConsumerState<ProfileKycScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reference = TextEditingController();
  String _docType = kKycDocumentTypes.first;
  CloudinaryUpload? _docUpload;
  bool _submitting = false;

  final _scrollController = ScrollController();

  Future<void> _changePhoto(AppUser user) async {
    final result =
        await pickAndUpload(context, folder: 'securebank/profiles/${user.id}');
    if (result != null) {
      await ref.read(kycRepositoryProvider).updatePhoto(user.id, result.url);
      Fluttertoast.showToast(msg: 'Profile photo updated');
    }
  }

  @override
  void dispose() {
    _reference.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submit(AppUser user) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref.read(kycRepositoryProvider).submitKyc(
            userId: user.id,
            userName: user.name,
            documentType: _docType,
            documentReference: _reference.text.trim(),
            documentUrl: _docUpload?.url ?? '',
          );
      _reference.clear();
      setState(() => _docUpload = null);
      Fluttertoast.showToast(msg: 'KYC submitted for review');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Submit failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          PremiumHeader(
            userId: widget.userId,
            title: 'Profile & KYC',
            scrollController: _scrollController,
            onNotificationsTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) =>
                        NotificationsScreen(userId: widget.userId))),
            onSettingsTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SettingsScreen(userId: widget.userId))),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                final userAsync = ref.watch(kycUserProvider(widget.userId));
                if (!userAsync.hasValue) {
                  return const Center(child: CircularProgressIndicator());
                }
                final user = userAsync.value!;
                final kyc =
                    ref.watch(latestKycProvider(widget.userId)).valueOrNull;
                final canSubmit = user.kycStatus == 'not_submitted' ||
                    user.kycStatus == 'rejected';
                return ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _profileCard(user),
                    const SizedBox(height: 20),
                    _kycStatusCard(user.kycStatus),
                    const SizedBox(height: 20),
                    if (kyc != null) _lastSubmissionCard(kyc),
                    if (kyc != null) const SizedBox(height: 20),
                    if (canSubmit)
                      _submitForm(user)
                    else if (user.kycStatus == 'pending')
                      _infoBanner(
                        Icons.hourglass_top,
                        AppColors.warning,
                        'Your KYC is under review. An administrator will '
                        'approve or reject it soon.',
                      )
                    else if (user.kycStatus == 'approved')
                      _infoBanner(
                        Icons.verified,
                        AppColors.success,
                        'Your identity has been verified. No further action '
                        'is needed.',
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileCard(AppUser user) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => _changePhoto(user),
                  child: Hero(
                    // Matches PremiumHeader's avatar Hero tag so tapping the
                    // header avatar flies into this profile photo.
                    tag: 'securebank-header-avatar',
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.12),
                          backgroundImage: user.photoUrl.isNotEmpty
                              ? NetworkImage(user.photoUrl)
                              : null,
                          child: user.photoUrl.isEmpty
                              ? Text(
                                  user.name.isNotEmpty
                                      ? user.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.photo_camera,
                                size: 13, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(user.role.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _row(Icons.email, user.email),
            const SizedBox(height: 8),
            _row(Icons.phone, user.phone.isEmpty ? '—' : user.phone),
            const SizedBox(height: 8),
            _row(user.status == 'active' ? Icons.check_circle : Icons.block,
                'Account ${user.status}'),
          ],
        ),
      );

  Widget _row(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      );

  Widget _kycStatusCard(String status) {
    late Color color;
    late String label;
    late IconData icon;
    switch (status) {
      case 'approved':
        color = AppColors.success;
        label = 'Verified';
        icon = Icons.verified;
        break;
      case 'pending':
        color = AppColors.warning;
        label = 'Pending review';
        icon = Icons.hourglass_top;
        break;
      case 'rejected':
        color = AppColors.danger;
        label = 'Rejected — please resubmit';
        icon = Icons.cancel;
        break;
      default:
        color = AppColors.textMuted;
        label = 'Not submitted';
        icon = Icons.badge_outlined;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Identity Verification (KYC)',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lastSubmissionCard(KycModel kyc) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Last submission',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 6),
            Text('${kyc.documentType} • ${kyc.documentReference}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
                'Submitted ${DateFormat.yMMMd().add_jm().format(kyc.createdAt)}',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      );

  Widget _submitForm(AppUser user) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Submit identity document',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              const Text(
                  'Choose your document type, enter its number, and attach a '
                  'clear photo. An admin will review and approve it.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _docType,
                decoration: const InputDecoration(
                    labelText: 'Document type', border: OutlineInputBorder()),
                items: kKycDocumentTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _docType = v!),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _reference,
                decoration: const InputDecoration(
                    labelText: 'Document number / reference',
                    border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().length < 4)
                    ? 'Enter a valid document number'
                    : null,
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _submitting
                    ? null
                    : () async {
                        final r = await pickAndUpload(context,
                            folder: 'securebank/kyc/${user.id}');
                        if (r != null) setState(() => _docUpload = r);
                      },
                icon: Icon(
                    _docUpload == null ? Icons.upload_file : Icons.check_circle,
                    color: _docUpload == null ? null : AppColors.success),
                label: Text(_docUpload == null
                    ? 'Attach document photo'
                    : 'Document photo attached'),
              ),
              if (_docUpload != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(_docUpload!.url,
                      height: 120, width: double.infinity, fit: BoxFit.cover),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitting ? null : () => _submit(user),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _submitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Submit for verification',
                        style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );

  Widget _infoBanner(IconData icon, Color color, String text) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
          ],
        ),
      );
}
