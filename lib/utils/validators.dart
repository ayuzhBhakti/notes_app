// The mobile number on the sign-in screen. India, the default, has a strict
// rule: it is where codes are delivered today and where UPI works.

import '../models/country.dart';

/// The ten digits of an Indian mobile number, or null if [value] is not one.
/// Spaces and dashes are how people type numbers, and a pasted number often
/// carries +91 or a leading 0.
String? normalizeIndianMobile(String? value) {
  String digits = (value ?? '').replaceAll(RegExp(r'[\s\-().]'), '');
  if (digits.startsWith('+91')) {
    digits = digits.substring(3);
  } else if (digits.length == 12 && digits.startsWith('91')) {
    digits = digits.substring(2);
  } else if (digits.length == 11 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  // Mobile numbers start with 6 to 9; anything else is a landline or a typo.
  return RegExp(r'^[6-9]\d{9}$').hasMatch(digits) ? digits : null;
}

/// An error message, or null when the value is acceptable.
String? validateIndianMobile(String? value) {
  if ((value ?? '').trim().isEmpty) return 'Enter your mobile number.';
  return normalizeIndianMobile(value) == null
      ? 'Enter a valid 10-digit mobile number.'
      : null;
}

// Any other country. Without a numbering-plan database the rule is only the
// international limit: a whole number is at most 15 digits, and no real
// mobile number has fewer than 6 after its country code. The SMS route
// decides the rest.

/// The national digits of a number in [country], or null if [value] cannot
/// be one. A leading 0 (the trunk prefix most countries dial at home) and a
/// pasted country code are removed.
String? normalizeNationalNumber(Country country, String? value) {
  if (country.isIndia) return normalizeIndianMobile(value);
  String digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
  final String typed = (value ?? '').trim();
  if (typed.startsWith('+') && digits.startsWith(country.dialCode)) {
    digits = digits.substring(country.dialCode.length);
  }
  digits = digits.replaceFirst(RegExp(r'^0+'), '');
  final int max = 15 - country.dialCode.length;
  return digits.length >= 6 && digits.length <= max ? digits : null;
}

/// An error message, or null when the value is acceptable.
String? validateNationalNumber(Country country, String? value) {
  if (country.isIndia) return validateIndianMobile(value);
  if ((value ?? '').trim().isEmpty) return 'Enter your mobile number.';
  return normalizeNationalNumber(country, value) == null
      ? 'Enter a valid mobile number.'
      : null;
}
