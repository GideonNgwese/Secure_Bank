import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../auth/presentation/widgets/app_text_field.dart';
import '../../auth/presentation/widgets/primary_button.dart';
import '../domain/profile_draft.dart';
import '../domain/profile_fields.dart';
import '../domain/profile_validators.dart';
import 'controllers/profile_completion_controller.dart';
import 'controllers/profile_draft_controller.dart';
import 'widgets/profile_date_field.dart';
import 'widgets/profile_dropdown_field.dart';
import 'widgets/profile_photo_picker.dart';

/// Shown by [AuthGate] once, right after signup/login, whenever the user's
/// `profileCompleted` flag is false. On success it writes straight to
/// Firestore and lets the gate's reactive stream swap to the Dashboard —
/// this screen never navigates directly.
class ProfileCompletionScreen extends ConsumerStatefulWidget {
  final AuthUser initial;
  const ProfileCompletionScreen({super.key, required this.initial});

  @override
  ConsumerState<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState
    extends ConsumerState<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _phone;
  late final TextEditingController _city;

  @override
  void initState() {
    super.initState();
    final u = widget.initial;
    final seeded = ProfileDraft.prefill(
      fullName: u.fullName,
      phone: u.phone,
      gender: u.gender,
      dateOfBirth: u.dateOfBirth,
      region: u.region,
      city: u.city,
      occupation: u.occupation,
      preferredCurrency: u.preferredCurrency,
      preferredLanguage: u.preferredLanguage,
      photoUrl: u.photoUrl,
    );
    _fullName = TextEditingController(text: seeded.fullName);
    _phone = TextEditingController(text: seeded.phone);
    _city = TextEditingController(text: seeded.city);
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(profileDraftProvider.notifier).seed(seeded));
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _city.dispose();
    super.dispose();
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _submit() async {
    final notifier = ref.read(profileDraftProvider.notifier);
    // Keep free-text controllers in sync with the draft before validating.
    notifier.setFullName(_fullName.text);
    notifier.setPhone(_phone.text);
    notifier.setCity(_city.text);

    final ok = _formKey.currentState!.validate();
    if (!ok) return;
    FocusScope.of(context).unfocus();

    final synced = ref.read(profileDraftProvider);
    // Errors are surfaced by the ref.listen in build() — on success, AuthGate's
    // live profile stream swaps this screen out for the Dashboard on its own.
    await ref
        .read(profileCompletionControllerProvider.notifier)
        .submit(widget.initial.uid, synced);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(profileCompletionControllerProvider, (_, next) {
      if (next is AsyncError) {
        _snack((next.error as AppException).message);
      }
    });
    final draft = ref.watch(profileDraftProvider);
    final saving = ref.watch(profileCompletionControllerProvider).isLoading;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 560,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: saving
                        ? null
                        : () =>
                            ref.read(authControllerProvider.notifier).signOut(),
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Log out'),
                  ),
                ),
                FadeSlideIn(child: _Header(uid: widget.initial.uid)),
                const SizedBox(height: 8),
                FadeSlideIn(
                  duration: const Duration(milliseconds: 500),
                  child: Center(
                    child: ProfilePhotoPicker(
                      userId: widget.initial.uid,
                      initialUrl: draft.photoUrl,
                      onUploaded: (url) => ref
                          .read(profileDraftProvider.notifier)
                          .setPhotoUrl(url),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FadeSlideIn(
                  duration: const Duration(milliseconds: 550),
                  child: _SectionCard(
                    title: 'Personal details',
                    icon: Icons.badge_outlined,
                    children: [
                      AppTextField(
                        controller: _fullName,
                        label: 'Full name',
                        icon: Icons.person_outline,
                        keyboardType: TextInputType.name,
                        validator: ProfileValidators.fullName,
                        onChanged: (v) => ref
                            .read(profileDraftProvider.notifier)
                            .setFullName(v),
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _phone,
                        label: 'Phone number',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                        ],
                        validator: ProfileValidators.phone,
                        onChanged: (v) =>
                            ref.read(profileDraftProvider.notifier).setPhone(v),
                      ),
                      const SizedBox(height: 14),
                      ProfileDropdownField(
                        label: 'Gender',
                        icon: Icons.wc_outlined,
                        value: draft.gender,
                        items: ProfileFields.genders,
                        onChanged: (v) => ref
                            .read(profileDraftProvider.notifier)
                            .setGender(v ?? ''),
                        validator: (v) =>
                            ProfileValidators.required(v, 'Gender'),
                      ),
                      const SizedBox(height: 14),
                      ProfileDateField(
                        label: 'Date of birth',
                        icon: Icons.cake_outlined,
                        value: draft.dateOfBirth,
                        onChanged: (v) => ref
                            .read(profileDraftProvider.notifier)
                            .setDateOfBirth(v),
                        validator: ProfileValidators.dateOfBirth,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FadeSlideIn(
                  duration: const Duration(milliseconds: 600),
                  child: _SectionCard(
                    title: 'Location',
                    icon: Icons.location_on_outlined,
                    children: [
                      ProfileDropdownField(
                        label: 'Region',
                        icon: Icons.map_outlined,
                        value: draft.region,
                        items: ProfileFields.regions,
                        onChanged: (v) => ref
                            .read(profileDraftProvider.notifier)
                            .setRegion(v ?? ''),
                        validator: (v) =>
                            ProfileValidators.required(v, 'Region'),
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _city,
                        label: 'City',
                        icon: Icons.location_city_outlined,
                        validator: (v) => ProfileValidators.required(v, 'City'),
                        onChanged: (v) =>
                            ref.read(profileDraftProvider.notifier).setCity(v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FadeSlideIn(
                  duration: const Duration(milliseconds: 650),
                  child: _SectionCard(
                    title: 'Preferences',
                    icon: Icons.tune_outlined,
                    children: [
                      ProfileDropdownField(
                        label: 'Occupation',
                        icon: Icons.work_outline,
                        value: draft.occupation,
                        items: ProfileFields.occupations,
                        onChanged: (v) => ref
                            .read(profileDraftProvider.notifier)
                            .setOccupation(v ?? ''),
                        validator: (v) =>
                            ProfileValidators.required(v, 'Occupation'),
                      ),
                      const SizedBox(height: 14),
                      ProfileDropdownField(
                        label: 'Preferred currency',
                        icon: Icons.attach_money,
                        value: draft.preferredCurrency,
                        items: ProfileFields.currencies,
                        onChanged: (v) => ref
                            .read(profileDraftProvider.notifier)
                            .setPreferredCurrency(v ?? 'FCFA'),
                      ),
                      const SizedBox(height: 14),
                      ProfileDropdownField(
                        label: 'Preferred language',
                        icon: Icons.language,
                        value: draft.preferredLanguage,
                        items: ProfileFields.languages,
                        onChanged: (v) => ref
                            .read(profileDraftProvider.notifier)
                            .setPreferredLanguage(v ?? 'English'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                FadeSlideIn(
                  duration: const Duration(milliseconds: 700),
                  child: PrimaryButton(
                    label: 'Continue to Dashboard',
                    loading: saving,
                    onPressed: _submit,
                    icon: Icons.arrow_forward_rounded,
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Your information is kept private and secure.',
                    style:
                        TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String uid;
  const _Header({required this.uid});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTokens.brand, AppTokens.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        boxShadow: [
          BoxShadow(
              color: AppTokens.brand.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 14)),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('One last step',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('Complete your profile',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text(
            "Tell us a bit about yourself so SecureBank can personalize your "
            'experience and keep your account secure.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard(
      {required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : scheme.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 6)),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTokens.brand),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
