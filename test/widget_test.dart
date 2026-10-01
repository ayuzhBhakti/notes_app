import 'package:flutter_test/flutter_test.dart';
import 'package:notes/models/note.dart';
import 'package:notes/utils/format.dart';

// A widget test that pumps the real app is deliberately not written here: the
// root widget requires Firebase.initializeApp, which fails under flutter_test
// without heavy platform-channel mocking. These cover the pure logic instead.

Note _note({String title = '', String body = '', DateTime? updatedAt}) => Note(
      id: 'test-id',
      title: title,
      body: body,
      createdAt: null,
      updatedAt: updatedAt,
      isPending: false,
    );

void main() {
  group('Note.displayTitle', () {
    test('uses the title when there is one', () {
      expect(_note(title: 'Groceries', body: 'milk').displayTitle, 'Groceries');
    });

    test('falls back to the first body line', () {
      expect(_note(body: 'milk\neggs').displayTitle, 'milk');
    });

    test('falls back to a placeholder when both are blank', () {
      expect(_note(body: '   ').displayTitle, 'Untitled note');
    });
  });

  group('Note.sortKey', () {
    test('is never null, so pending notes still sort', () {
      expect(_note().sortKey, isA<DateTime>());
    });

    test('uses updatedAt once the server timestamp resolves', () {
      final DateTime when = DateTime(2026, 1, 2, 3, 4);
      expect(_note(updatedAt: when).sortKey, when);
    });
  });

  group('formatNoteTime', () {
    test('reports a pending write rather than a blank', () {
      expect(formatNoteTime(null), 'Saving…');
    });

    test('collapses the last minute to "Just now"', () {
      expect(
        formatNoteTime(DateTime.now().subtract(const Duration(seconds: 5))),
        'Just now',
      );
    });

    test('uses relative units within the week', () {
      expect(
        formatNoteTime(DateTime.now().subtract(const Duration(hours: 3))),
        '3h ago',
      );
    });
  });
}
