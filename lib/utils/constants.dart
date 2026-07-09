import 'package:flutter/material.dart';

/// App-wide constants for SecureBank
class AppColors {
  // Aligned with the SecureBank logo (blue → purple).
  static const primary = Color(0xFF3E74FF);
  static const primaryDark = Color(0xFF2348C8);
  static const accent = Color(0xFF9B37E0); // logo purple
  static const success = Color(0xFF1FA96A);
  static const warning = Color(0xFFE8A33D);
  static const danger = Color(0xFFE84C4C);
  static const critical = Color(0xFF7A0C0C); // dark red — Critical risk
  static const bg = Color(0xFFF5F7FB);
  static const card = Colors.white;
  static const textMuted = Color(0xFF7A8699);
}

/// Account providers supported (bank + mobile money + cash), Cameroon-focused.
const List<String> kProviders = [
  'MTN Mobile Money',
  'Orange Money',
  'Yoomee Money',
  'UBA',
  'Afriland First Bank',
  'Ecobank',
  'BGFI Bank',
  'SCB Cameroon',
  'Access Bank',
  'Standard Chartered',
  'Cash',
  'Other',
];

const List<String> kAccountTypes = [
  'Bank',
  'Mobile Money',
  'Cash',
  'Savings',
  'Business',
];

/// Spending / income categories — shared by Transactions and Budgets so a
/// budget category always matches a selectable transaction category. Users
/// can also add their own custom categories from the transaction form.
const List<String> kCategories = [
  'Salary',
  'Business',
  'Food',
  'Transport',
  'Shopping',
  'Bills',
  'Entertainment',
  'Healthcare',
  'Education',
  'Savings',
  'Investment',
  'Utilities',
  'Travel',
  'Gift',
  'Rent',
  'Insurance',
  'Taxes',
  'Loan',
  'Mobile Money',
  'Cash',
  'Others',
];

/// KYC document types accepted for identity verification
const List<String> kKycDocumentTypes = [
  'National ID Card',
  'Passport',
  "Driver's License",
  'Voter Card',
];

/// Fraud-risk level colors: Low = blue, Medium = orange, High = red,
/// Critical = dark red.
Color riskColor(String level) {
  switch (level) {
    case 'Critical':
      return AppColors.critical;
    case 'High':
      return AppColors.danger;
    case 'Medium':
      return AppColors.warning;
    case 'Low':
      return AppColors.primary;
    default:
      return AppColors.textMuted;
  }
}

String formatFCFA(double amount) {
  final isNegative = amount < 0;
  final value = amount.abs().toStringAsFixed(0);
  final buffer = StringBuffer();
  for (int i = 0; i < value.length; i++) {
    if (i != 0 && (value.length - i) % 3 == 0) buffer.write(',');
    buffer.write(value[i]);
  }
  return '${isNegative ? '-' : ''}$buffer FCFA';
}
