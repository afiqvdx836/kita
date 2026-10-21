import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/days.dart';
import 'models.dart';

/// All Supabase access in one place. RLS on the server scopes every query to
/// the signed-in user's couple, so filters here are for realtime efficiency.
class Repo {
  Repo._();
  static final instance = Repo._();

  SupabaseClient get _db => Supabase.instance.client;

  String get uid => _db.auth.currentUser!.id;

  // ------------------------------------------------------------ auth

  Stream<AuthState> get authChanges => _db.auth.onAuthStateChange;
  Session? get session => _db.auth.currentSession;

  /// Returns true when a session started; false when email confirmation is on.
  Future<bool> signUp(String email, String password, String name) async {
    final res = await _db.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': name},
    );
    return res.session != null;
  }

  Future<void> signIn(String email, String password) =>
      _db.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() => _db.auth.signOut();

  // ------------------------------------------------------------ couple

  Stream<Profile?> watchMe() => _db
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', uid)
      .map((rows) => rows.isEmpty ? null : Profile.fromMap(rows.first));

  Stream<List<Profile>> watchMembers(String coupleId) => _db
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('couple_id', coupleId)
      .map((rows) => rows.map(Profile.fromMap).toList());

  Stream<Couple?> watchCouple(String coupleId) => _db
      .from('couples')
      .stream(primaryKey: ['id'])
      .eq('id', coupleId)
      .map((rows) => rows.isEmpty ? null : Couple.fromMap(rows.first));

  Future<String> createInvite() async =>
      await _db.rpc('create_invite') as String;

  Future<void> joinCouple(String code) =>
      _db.rpc('join_couple', params: {'p_code': code.trim()});

  Future<void> leaveCouple() => _db.rpc('leave_couple');

  Future<void> setTogetherSince(String coupleId, DateTime date) => _db
      .from('couples')
      .update({'together_since': formatDate(date)}).eq('id', coupleId);

  // ------------------------------------------------------------ notes

  Stream<List<Note>> watchNotes(String coupleId) => _db
      .from('notes')
      .stream(primaryKey: ['id'])
      .eq('couple_id', coupleId)
      .order('updated_at')
      .map((rows) {
        final notes = rows.map(Note.fromMap).toList();
        notes.sort((a, b) {
          if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
          return b.updatedAt.compareTo(a.updatedAt);
        });
        return notes;
      });

  Future<void> saveNote({
    required String coupleId,
    String? id,
    required String title,
    required String body,
    bool pinned = false,
  }) {
    final values = {'title': title, 'body': body, 'pinned': pinned};
    if (id == null) {
      return _db
          .from('notes')
          .insert({...values, 'couple_id': coupleId, 'author_id': uid});
    }
    return _db.from('notes').update(values).eq('id', id);
  }

  Future<void> deleteNote(String id) =>
      _db.from('notes').delete().eq('id', id);

  // ------------------------------------------------------------ tasks

  Stream<List<Task>> watchTasks(String coupleId) => _db
      .from('tasks')
      .stream(primaryKey: ['id'])
      .eq('couple_id', coupleId)
      .order('created_at')
      .map((rows) {
        final tasks = rows.map(Task.fromMap).toList();
        tasks.sort((a, b) {
          if (a.done != b.done) return a.done ? 1 : -1;
          return a.createdAt.compareTo(b.createdAt);
        });
        return tasks;
      });

  Future<void> addTask(String coupleId, String title) => _db.from('tasks').insert(
        {'couple_id': coupleId, 'created_by': uid, 'title': title.trim()},
      );

  Future<void> setTaskDone(String id, bool done) =>
      _db.from('tasks').update({'done': done}).eq('id', id);

  Future<void> deleteTask(String id) =>
      _db.from('tasks').delete().eq('id', id);
}

/// Turns server errors into short messages for a SnackBar.
String friendlyError(Object e) {
  final raw = switch (e) {
    PostgrestException(:final message) => message,
    AuthException(:final message) => message,
    _ => e.toString(),
  };
  const known = {
    'invalid_code': 'That code is wrong or has expired.',
    'own_code': 'That is your own code. Send it to your partner instead.',
    'couple_full': 'That couple already has two people.',
    'already_paired': 'You are already paired with someone.',
    'not_authenticated': 'Please sign in again.',
  };
  for (final entry in known.entries) {
    if (raw.contains(entry.key)) return entry.value;
  }
  return raw;
}
