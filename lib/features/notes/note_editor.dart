import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/repo.dart';

class NoteEditor extends StatefulWidget {
  const NoteEditor({super.key, required this.coupleId, this.note});

  final String coupleId;
  final Note? note;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final _title = TextEditingController(text: widget.note?.title);
  late final _body = TextEditingController(text: widget.note?.body);
  late bool _pinned = widget.note?.pinned ?? false;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _act(Future<void> Function() action) async {
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() {
    if (_title.text.trim().isEmpty && _body.text.trim().isEmpty) {
      Navigator.of(context).pop();
      return Future.value();
    }
    return _act(() => Repo.instance.saveNote(
          coupleId: widget.coupleId,
          id: widget.note?.id,
          title: _title.text.trim(),
          body: _body.text,
          pinned: _pinned,
        ));
  }

  Future<void> _delete() => _act(() => Repo.instance.deleteNote(widget.note!.id));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'New note' : 'Edit note'),
        actions: [
          IconButton(
            tooltip: _pinned ? 'Unpin' : 'Pin',
            icon: Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined),
            onPressed: () => setState(() => _pinned = !_pinned),
          ),
          if (widget.note != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : _delete,
            ),
          IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.check),
            onPressed: _busy ? null : _save,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            TextField(
              controller: _title,
              style: text.titleLarge,
              decoration: const InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            Expanded(
              child: TextField(
                controller: _body,
                decoration: const InputDecoration(
                  hintText: 'Write something for the two of you…',
                  border: InputBorder.none,
                ),
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
