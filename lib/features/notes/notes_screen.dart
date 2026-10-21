import 'package:flutter/material.dart';

import '../../core/stream_view.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import 'note_editor.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key, required this.coupleId, required this.nameOf});

  final String coupleId;
  final String Function(String? id) nameOf;

  void _open(BuildContext context, [Note? note]) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NoteEditor(coupleId: coupleId, note: note),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New note',
        onPressed: () => _open(context),
        child: const Icon(Icons.add),
      ),
      body: StreamView<List<Note>>(
        create: () => Repo.instance.watchNotes(coupleId),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(friendlyError(snap.error!)));
          }
          final notes = snap.data;
          if (notes == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (notes.isEmpty) {
            return const Center(child: Text('No notes yet. Write the first one.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: notes.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final note = notes[i];
              final title = note.title.isEmpty ? 'Untitled' : note.title;
              return ListTile(
                leading: note.pinned ? const Icon(Icons.push_pin) : null,
                title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [
                    if (note.body.isNotEmpty) note.body.replaceAll('\n', ' '),
                    'by ${nameOf(note.authorId)}',
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _open(context, note),
              );
            },
          );
        },
      ),
    );
  }
}
