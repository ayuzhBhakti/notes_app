import 'package:cloud_firestore/cloud_firestore.dart';

/// A single note, as stored at `users/{uid}/notes/{noteId}`.
///
/// `ownerId` is deliberately not a field — it is redundant with the document
/// path, and the security rules' `hasOnly()` check would reject it.
class Note {
  const Note({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    required this.isPending,
  });

  final String id;
  final String title;
  final String body;

  /// Null while `FieldValue.serverTimestamp()` is still unresolved.
  ///
  /// This nullability is forced, not a style choice: `cloud_firestore` exposes no
  /// `serverTimestampBehavior` — its `SnapshotOptions` is an empty class
  /// documented "Currently unsupported by FlutterFire" — so there is no way to
  /// ask for a local estimate. A just-written note reads back with null
  /// timestamps for roughly 100–300ms.
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// `snapshot.metadata.hasPendingWrites` — committed locally, not yet
  /// acknowledged by the server.
  final bool isPending;

  /// Never null, so ordering is total in every state: pending, cached, settled.
  DateTime get sortKey => updatedAt ?? DateTime.now();

  /// A note with no title still needs something to show in the list.
  String get displayTitle {
    final String trimmed = title.trim();
    if (trimmed.isNotEmpty) return trimmed;
    final String firstLine = body.trim().split('\n').first.trim();
    return firstLine.isEmpty ? 'Untitled note' : firstLine;
  }

  static Note fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};
    return Note(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isPending: doc.metadata.hasPendingWrites,
    );
  }
}
