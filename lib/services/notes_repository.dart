import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/note.dart';

/// The only file in the app that imports `cloud_firestore`.
///
/// `uid` is a per-call argument rather than constructor state, so this object
/// can never be in a "signed out but still alive" state and its provider never
/// has to throw.
class NotesRepository {
  const NotesRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _notes(String uid) =>
      _db.collection('users').doc(uid).collection('notes');

  /// Live, newest first.
  Stream<List<Note>> watchNotes(String uid) {
    return _notes(uid)
        // Subcollections are ordinary collections, so `updatedAt` descending is
        // served by Firestore's automatic single-field index. No composite
        // index and no firestore.indexes.json entry are needed.
        .orderBy('updatedAt', descending: true)
        // includeMetadataChanges stays false: true costs an extra rebuild per
        // document purely for the pending -> acknowledged metadata flip.
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
      final List<Note> notes = snapshot.docs.map(Note.fromDoc).toList();
      // Re-sort locally. Where the native query engine places an unresolved
      // server timestamp under `descending: true` is unspecified, so a
      // just-created note could visibly jump between top and bottom for a few
      // hundred milliseconds. sortKey pins pending notes to the top, making
      // newest-first deterministic in every state. The list is personal-sized,
      // so this costs nothing.
      notes.sort((Note a, Note b) => b.sortKey.compareTo(a.sortKey));
      return notes;
    });
  }

  /// Both timestamps are server-stamped. The rules require `== request.time`,
  /// which is what makes them trustworthy for ordering — device clocks are
  /// user-settable, and a client-side `DateTime.now()` is rejected outright.
  Future<void> create(
    String uid, {
    required String title,
    required String body,
  }) {
    return _notes(uid).doc().set(<String, Object?>{
      'title': title,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// `createdAt` is deliberately absent — the rules reject an update that
  /// changes it, and `update()` leaves untouched fields alone.
  Future<void> update(
    String uid,
    String id, {
    required String title,
    required String body,
  }) {
    return _notes(uid).doc(id).update(<String, Object?>{
      'title': title,
      'body': body,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> delete(String uid, String id) => _notes(uid).doc(id).delete();

  /// Undo support. Reuses the same document id.
  ///
  /// In rules terms this is a create, so `createdAt` is necessarily re-stamped.
  /// That is accepted deliberately: nothing in the UI displays `createdAt`, and
  /// the alternative (a `deletedAt` tombstone) would need a filter in every
  /// query, an extra rules branch, and eventually a purge job.
  Future<void> restore(String uid, Note note) {
    return _notes(uid).doc(note.id).set(<String, Object?>{
      'title': note.title,
      'body': note.body,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
