import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:google_sign_in/google_sign_in.dart';

import '../services/auth_service.dart' show SignInCanceled;
import '../services/evos_backend.dart' show BackendError, BackendFailure;
import '../services/payment_gateway.dart' show PaymentError, PaymentFailure;

/// A failure rendered for a human, with an optional actionable hint.
class AppFailure {
  const AppFailure(this.message, {this.hint});

  final String message;
  final String? hint;
}

/// A short, stable name for an error, for analytics. Never the error's
/// message: that is free text and can contain an email address or a document
/// path.
String errorCode(Object error) {
  if (error is ProviderException) return errorCode(error.exception);
  if (error is GoogleSignInException) return error.code.name;
  if (error is BackendFailure) return error.kind.name;
  if (error is PaymentFailure) return error.code ?? error.kind.name;
  // Covers FirebaseAuthException, which extends it.
  if (error is FirebaseException) return error.code;
  return error.runtimeType.toString();
}

/// Maps any thrown object to something worth showing a user.
AppFailure describeError(Object error) {
  // Riverpod 3 wraps errors that propagate through ref.watch/ref.read. Unwrap
  // first or every message would read "ProviderException".
  if (error is ProviderException) {
    return describeError(error.exception);
  }

  if (error is SignInCanceled) {
    return const AppFailure('Sign-in was cancelled.');
  }

  if (error is BackendFailure) {
    return switch (error.kind) {
      BackendError.network => const AppFailure(
          "We couldn't reach the server.",
          hint: 'Check your connection and try again.',
        ),
      BackendError.invalidPhone =>
        const AppFailure('Enter a valid 10-digit mobile number.'),
      BackendError.tooManyRequests => const AppFailure(
          'Too many attempts.',
          hint: 'Wait a minute, then try again.',
        ),
      BackendError.wrongCode => const AppFailure(
          "That code isn't right, or it has expired.",
          hint: 'Check the SMS, or ask for a new code.',
        ),
      BackendError.signedOut =>
        const AppFailure('You have been signed out. Sign in again.'),
      BackendError.alreadySubscribed =>
        const AppFailure('Your subscription is already active.'),
      BackendError.notConfigured ||
      BackendError.server =>
        const AppFailure('Something went wrong on our side. Try again.'),
    };
  }

  if (error is PaymentFailure) {
    return switch (error.kind) {
      PaymentError.upiAppUnavailable => const AppFailure(
          "That UPI app couldn't be opened.",
          hint: 'Choose another UPI app.',
        ),
      PaymentError.declined => const AppFailure(
          "The payment didn't go through.",
          hint: 'Nothing was charged. Try again, or use another UPI app.',
        ),
      PaymentError.pending => const AppFailure(
          "We're still confirming your payment.",
          hint: 'This can take a minute. Close the app and open it again; '
              'if the payment went through, you will be let in.',
        ),
      PaymentError.unsupported =>
        const AppFailure('Payments are not available on this device.'),
    };
  }

  if (error is GoogleSignInException) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return const AppFailure('Sign-in was cancelled.');
      case GoogleSignInExceptionCode.interrupted:
        return const AppFailure(
          'Sign-in was interrupted. Please try again.',
        );
      case GoogleSignInExceptionCode.clientConfigurationError:
        return const AppFailure(
          'This app is misconfigured for Google sign-in.',
          hint: 'The OAuth client ID is missing or wrong.',
        );
      case GoogleSignInExceptionCode.providerConfigurationError:
        return const AppFailure(
          'Google Play services could not complete sign-in.',
          hint: 'Check that Google Play services is up to date.',
        );
      case GoogleSignInExceptionCode.uiUnavailable:
        return const AppFailure(
          'The sign-in screen could not be shown right now.',
        );
      case GoogleSignInExceptionCode.userMismatch:
        return const AppFailure(
          'That is a different account than the one expected.',
        );
      case GoogleSignInExceptionCode.unknownError:
        return AppFailure(
          'Google sign-in failed.',
          hint: error.description,
        );
    }
  }

  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'operation-not-allowed':
        return const AppFailure(
          'Google sign-in is not enabled for this project.',
          hint: 'Enable it under Authentication → Sign-in method.',
        );
      case 'account-exists-with-different-credential':
        return const AppFailure(
          'An account already exists with this email address.',
        );
      case 'network-request-failed':
        return const AppFailure('No network connection.');
      case 'missing-google-id-token':
        return const AppFailure(
          'Google did not return an ID token.',
          hint: 'Check that the server client ID matches this Firebase project.',
        );
      default:
        return AppFailure(error.message ?? 'Authentication failed.');
    }
  }

  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return const AppFailure(
          "You do not have permission to do that.",
          hint: 'Check that the Firestore security rules are published.',
        );
      case 'unauthenticated':
        return const AppFailure('You are signed out.');
      case 'unavailable':
        return const AppFailure(
          'Cannot reach Firestore. Your changes are saved locally and will '
          'sync when you are back online.',
        );
      default:
        return AppFailure(error.message ?? 'Something went wrong.');
    }
  }

  if (error is StateError) return AppFailure(error.message);

  return const AppFailure('Something went wrong.');
}
