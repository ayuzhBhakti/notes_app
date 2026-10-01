// Field validators for the onboarding details form. Each returns an error
// message, or null when the value is acceptable.
//
// The upper limits mirror the column checks on the Supabase table. Without
// them an over-long value would pass here, be rejected by the server, and
// show the user a "couldn't save" message that says nothing about length.

String? validateName(String? value) {
  final String text = value?.trim() ?? '';
  if (text.isEmpty) return 'Enter your name.';
  if (text.length < 2) return 'That name is too short.';
  if (text.length > 200) return 'That name is too long.';
  return null;
}

// Deliberately loose: something@something.tld with no spaces. Whether the
// address exists can only be proven by sending mail to it.
final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? value) {
  final String text = value?.trim() ?? '';
  if (text.isEmpty) return 'Enter your email address.';
  if (text.length > 320 || !_email.hasMatch(text)) {
    return 'Enter a valid email address.';
  }
  return null;
}

String? validatePhone(String? value) {
  final String text = value?.trim() ?? '';
  if (text.isEmpty) return 'Enter your phone number.';
  // The text is stored as typed, so its length is limited as well as its
  // digit count.
  if (text.length > 32) return 'Enter a valid phone number.';
  // Spaces, dashes, dots and brackets are how people type numbers.
  final String digits = text.replaceAll(RegExp(r'[\s\-().]'), '');
  // 7 to 15 digits is the E.164 range; a leading + is optional.
  if (!RegExp(r'^\+?\d{7,15}$').hasMatch(digits)) {
    return 'Enter a valid phone number.';
  }
  return null;
}

String? validateAddress(String? value) {
  final String text = value?.trim() ?? '';
  if (text.isEmpty) return 'Enter your address.';
  if (text.length < 5) return 'That address is too short.';
  if (text.length > 1000) return 'That address is too long.';
  return null;
}
