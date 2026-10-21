import '../core/days.dart';

class Profile {
  const Profile({required this.id, required this.displayName, this.coupleId});

  final String id;
  final String displayName;
  final String? coupleId;

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        displayName: (m['display_name'] as String?) ?? '',
        coupleId: m['couple_id'] as String?,
      );

  String get label => displayName.isEmpty ? 'You' : displayName;
}

class Couple {
  const Couple({required this.id, this.togetherSince});

  final String id;
  final DateTime? togetherSince;

  factory Couple.fromMap(Map<String, dynamic> m) => Couple(
        id: m['id'] as String,
        togetherSince: parseDate(m['together_since']),
      );
}

class Note {
  const Note({
    required this.id,
    required this.title,
    required this.body,
    required this.pinned,
    required this.updatedAt,
    this.authorId,
  });

  final String id;
  final String title;
  final String body;
  final bool pinned;
  final DateTime updatedAt;
  final String? authorId;

  factory Note.fromMap(Map<String, dynamic> m) => Note(
        id: m['id'] as String,
        title: (m['title'] as String?) ?? '',
        body: (m['body'] as String?) ?? '',
        pinned: (m['pinned'] as bool?) ?? false,
        updatedAt: DateTime.parse(m['updated_at'] as String).toLocal(),
        authorId: m['author_id'] as String?,
      );
}

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.done,
    required this.createdAt,
    this.createdBy,
    this.doneBy,
    this.dueDate,
  });

  final String id;
  final String title;
  final bool done;
  final DateTime createdAt;
  final String? createdBy;
  final String? doneBy;
  final DateTime? dueDate;

  factory Task.fromMap(Map<String, dynamic> m) => Task(
        id: m['id'] as String,
        title: m['title'] as String,
        done: (m['done'] as bool?) ?? false,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        createdBy: m['created_by'] as String?,
        doneBy: m['done_by'] as String?,
        dueDate: parseDate(m['due_date']),
      );
}
