import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:supabase/supabase.dart';

import '../models/onboarding.dart';

/// The Supabase table the onboarding form is written to.
const String kLeadsTable = 'onboarding_leads';

/// The details could not be saved. Carries no cause: the user can do nothing
/// with a Postgres or socket error except try again.
class LeadSaveFailure implements Exception {
  const LeadSaveFailure();

  @override
  String toString() => 'LeadSaveFailure';
}

abstract class LeadsRepository {
  /// Completes once the server has stored the details. Throws
  /// [LeadSaveFailure] otherwise.
  Future<void> save(LeadDetails details);
}

/// The only file in the app that imports `supabase`.
///
/// The pure-Dart client is used rather than `supabase_flutter`, which would
/// add an auth deep-link plugin that competes with DeepLinkService for
/// incoming links. Nothing here needs auth: the app only inserts, as anon.
class SupabaseLeadsRepository implements LeadsRepository {
  SupabaseLeadsRepository(String url, String anonKey)
      : _client = SupabaseClient(url, anonKey);

  final SupabaseClient _client;

  @override
  Future<void> save(LeadDetails details) async {
    try {
      // No `.select()`: the table's policy lets anon insert but not read, and
      // asking for the row back would turn a successful insert into an error.
      await _client
          .from(kLeadsTable)
          .insert(details.toJson())
          .timeout(const Duration(seconds: 15));
    } catch (error) {
      if (kDebugMode) debugPrint('[leads] Saving to Supabase failed: $error');
      throw const LeadSaveFailure();
    }
  }

  Future<void> dispose() => _client.dispose();
}

/// Used when the build was given no Supabase project.
///
/// A debug build carries on so the flow can be developed and tested without
/// credentials. A release build refuses: silently dropping every lead is worse
/// than a visible error.
class UnconfiguredLeadsRepository implements LeadsRepository {
  const UnconfiguredLeadsRepository();

  @override
  Future<void> save(LeadDetails details) async {
    if (!kDebugMode) throw const LeadSaveFailure();
    debugPrint(
      '[leads] Supabase is not configured, so these details were NOT saved.\n'
      '        Pass --dart-define=SUPABASE_URL=... and\n'
      '        --dart-define=SUPABASE_ANON_KEY=... to save them.',
    );
  }
}
