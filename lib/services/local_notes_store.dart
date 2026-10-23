import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../models/note.dart';
import 'onboarding_store.dart';

/// Device-local notes for the store-review number, which signs in on the
/// device and has no Firebase identity (see `review_account.dart`). The real
/// notes app uses Firestore through [NotesRepository]; this one is a complete
/// stand-in so that number gets a working notes screen without any backend.
///
/// Not synced and not backed up: the notes live only in `shared_preferences`,
/// through [OnboardingStore] (the one file that holds it), and go when the
/// app's data is cleared. Timestamps are the device clock, resolved at once,
/// so no note is ever [Note.isPending].
class LocalNotesStore {
  LocalNotesStore(this._store) {
    _notes = _decode(_store.loadNotes());
    // Replays the current list to each new subscriber through onListen, which
    // a plain broadcast stream would not.
    _controller = StreamController<List<Note>>.broadcast(onListen: _emit);
  }

  final OnboardingStore _store;
  final Random _random = Random();

  late List<Note> _notes;
  late final StreamController<List<Note>> _controller;

  /// Newest edit first, like the Firestore list.
  Stream<List<Note>> watch() => _controller.stream;

  void dispose() => unawaited(_controller.close());

  void _emit() {
    if (_controller.isClosed) return;
    final List<Note> sorted = <Note>[..._notes]
      ..sort((Note a, Note b) => b.sortKey.compareTo(a.sortKey));
    _controller.add(List<Note>.unmodifiable(sorted));
  }

  Future<void> _persist() async {
    await _store.saveNotes(_encode(_notes));
    _emit();
  }

  Future<void> create({required String title, required String body}) {
    final DateTime now = DateTime.now();
    _notes = <Note>[
      ..._notes,
      Note(
        id: '${now.microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}',
        title: title,
        body: body,
        createdAt: now,
        updatedAt: now,
        isPending: false,
      ),
    ];
    return _persist();
  }

  Future<void> update(String id, {required String title, required String body}) {
    _notes = <Note>[
      for (final Note note in _notes)
        if (note.id == id)
          Note(
            id: note.id,
            title: title,
            body: body,
            createdAt: note.createdAt,
            updatedAt: DateTime.now(),
            isPending: false,
          )
        else
          note,
    ];
    return _persist();
  }

  Future<void> delete(String id) {
    _notes = _notes.where((Note note) => note.id != id).toList();
    return _persist();
  }

  /// Undo. Re-stamps `updatedAt` so the note returns to the top, matching the
  /// Firestore path.
  Future<void> restore(Note note) {
    _notes = <Note>[
      ..._notes.where((Note n) => n.id != note.id),
      Note(
        id: note.id,
        title: note.title,
        body: note.body,
        createdAt: note.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        isPending: false,
      ),
    ];
    return _persist();
  }

  List<Note> _decode(String? source) {
    if (source == null) return <Note>[];
    try {
      final List<dynamic> list = jsonDecode(source) as List<dynamic>;
      return <Note>[
        for (final dynamic item in list)
          if (item is Map<String, dynamic>)
            Note(
              id: item['id'] as String,
              title: item['title'] as String? ?? '',
              body: item['body'] as String? ?? '',
              createdAt:
                  DateTime.fromMillisecondsSinceEpoch(item['createdAt'] as int),
              updatedAt:
                  DateTime.fromMillisecondsSinceEpoch(item['updatedAt'] as int),
              isPending: false,
            ),
      ];
    } catch (_) {
      // Corrupt data must not crash the notes screen; start empty instead.
      return <Note>[];
    }
  }

  String _encode(List<Note> notes) => jsonEncode(<Map<String, Object?>>[
        for (final Note note in notes)
          <String, Object?>{
            'id': note.id,
            'title': note.title,
            'body': note.body,
            'createdAt':
                (note.createdAt ?? DateTime.now()).millisecondsSinceEpoch,
            'updatedAt':
                (note.updatedAt ?? DateTime.now()).millisecondsSinceEpoch,
          },
      ]);
}
