// The mobile number on the sign-in screen. India only: the code is sent by an
// Indian SMS route and the subscription is paid over UPI.

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
