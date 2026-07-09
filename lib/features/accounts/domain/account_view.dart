import 'package:flutter/material.dart';
import '../../../models/account_model.dart';

/// An account with its computed current balance.
class AccountWithBalance {
  final AccountModel account;
  final double balance;
  const AccountWithBalance(this.account, this.balance);
}

enum AccountSort { newest, balanceHigh, balanceLow, name }

extension AccountSortLabel on AccountSort {
  String get label => switch (this) {
        AccountSort.newest => 'Newest',
        AccountSort.balanceHigh => 'Balance: high → low',
        AccountSort.balanceLow => 'Balance: low → high',
        AccountSort.name => 'Name (A–Z)',
      };
}

/// Search / filter / sort state for the accounts list.
class AccountQuery {
  final String search;
  final String? type; // null = all
  final String? provider; // null = all
  final AccountSort sort;
  final bool showArchived;

  const AccountQuery({
    this.search = '',
    this.type,
    this.provider,
    this.sort = AccountSort.newest,
    this.showArchived = false,
  });

  AccountQuery copyWith({
    String? search,
    String? Function()? type,
    String? Function()? provider,
    AccountSort? sort,
    bool? showArchived,
  }) =>
      AccountQuery(
        search: search ?? this.search,
        type: type != null ? type() : this.type,
        provider: provider != null ? provider() : this.provider,
        sort: sort ?? this.sort,
        showArchived: showArchived ?? this.showArchived,
      );

  bool get hasActiveFilters =>
      type != null || provider != null || search.isNotEmpty || showArchived;
}

/// Provider-derived branding (icon + gradient) for consistent, premium cards.
/// Keeping this derived from the provider means every "MTN MoMo" looks the same.
class ProviderBranding {
  ProviderBranding._();

  static ({IconData icon, List<Color> gradient}) of(
      String provider, String accountType) {
    switch (provider) {
      case 'MTN Mobile Money':
        return (
          icon: Icons.smartphone,
          gradient: [const Color(0xFFFFC107), const Color(0xFFFF8F00)]
        );
      case 'Orange Money':
        return (
          icon: Icons.smartphone,
          gradient: [const Color(0xFFFF8A00), const Color(0xFFE0218A)]
        );
      case 'Yoomee Money':
        return (
          icon: Icons.smartphone,
          gradient: [const Color(0xFF00B4DB), const Color(0xFF0083B0)]
        );
      case 'UBA':
        return (
          icon: Icons.account_balance,
          gradient: [const Color(0xFFD71920), const Color(0xFF8E0F14)]
        );
      case 'Afriland First Bank':
        return (
          icon: Icons.account_balance,
          gradient: [const Color(0xFF1B7A3D), const Color(0xFF0E4322)]
        );
      case 'Ecobank':
        return (
          icon: Icons.account_balance,
          gradient: [const Color(0xFF00447C), const Color(0xFF002B4E)]
        );
      case 'BGFI Bank':
        return (
          icon: Icons.account_balance,
          gradient: [const Color(0xFF16324F), const Color(0xFF0B1B2C)]
        );
      case 'SCB Cameroon':
        return (
          icon: Icons.account_balance,
          gradient: [const Color(0xFF2E5BFF), const Color(0xFF1B3BD1)]
        );
      case 'Access Bank':
        return (
          icon: Icons.account_balance,
          gradient: [const Color(0xFFE95D2A), const Color(0xFF7A2BE2)]
        );
      case 'Standard Chartered':
        return (
          icon: Icons.account_balance,
          gradient: [const Color(0xFF0473EA), const Color(0xFF1FA96A)]
        );
      case 'Cash':
        return (
          icon: Icons.payments,
          gradient: [const Color(0xFF1FA96A), const Color(0xFF147A4D)]
        );
      default:
        // Fall back on the account type for icon.
        final icon = switch (accountType) {
          'Savings' => Icons.savings,
          'Business' => Icons.storefront,
          'Cash' => Icons.payments,
          'Mobile Money' => Icons.smartphone,
          _ => Icons.account_balance_wallet,
        };
        return (
          icon: icon,
          gradient: [const Color(0xFF3E74FF), const Color(0xFF9B37E0)]
        );
    }
  }
}
