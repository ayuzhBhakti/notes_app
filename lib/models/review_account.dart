import 'country.dart';

/// The sign-in given to store reviewers (Play Console, "App access"), who
/// cannot receive an SMS on an Indian number or pay by UPI.
///
/// It is checked on the device: no code is sent, the code is always
/// [kReviewCode], and it skips the paywall onto the same web page every
/// subscriber gets, so a reviewer sees what paying users see.
const String kReviewPhone = '9931133385';
const String kReviewCode = '123456';

/// [phone] is the national number as the mobile-number screen hands it over.
bool isReviewAccount(Country country, String phone) =>
    country.dialCode == kIndia.dialCode && phone == kReviewPhone;
