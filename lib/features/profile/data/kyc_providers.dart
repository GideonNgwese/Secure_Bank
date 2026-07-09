import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/kyc_model.dart';
import '../../../models/user_model.dart';
import 'kyc_repository.dart';

final kycRepositoryProvider = Provider<KycRepository>((ref) => KycRepository());

final kycUserProvider = StreamProvider.family<AppUser?, String>(
    (ref, userId) => ref.watch(kycRepositoryProvider).watchUser(userId));

final latestKycProvider = StreamProvider.family<KycModel?, String>(
    (ref, userId) => ref.watch(kycRepositoryProvider).watchLatestKyc(userId));
