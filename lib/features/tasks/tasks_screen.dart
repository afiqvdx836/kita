import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/repo.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, required this.coupleId, required this.nameOf});

  final String coupleId;
  final String Function(String? id) nameOf;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _input = TextEditingController();
  late final Stream<List<Task>> _tasks = Repo.instance.watchTasks(widget.coupleId);

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _add() async {
    final title = _input.text.trim();
    if (title.isEmpty) return;
    _input.clear();
    await _guard(() => Repo.instance.addTask(widget.coupleId, title));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    decoration: const InputDecoration(
                      hintText: 'Add a task for the two of you',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(),
                  ),
                ),
                IconButton(
                  tooltip: 'Add',
                  icon: const Icon(Icons.add_circle),
                  onPressed: _add,
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Task>>(
              stream: _tasks,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text(friendlyError(snap.error!)));
                }
                final tasks = snap.data;
                if (tasks == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (tasks.isEmpty) {
                  return const Center(child: Text('Nothing to do. Enjoy it.'));
                }
                return ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, i) {
                    final task = tasks[i];
                    return Dismissible(
                      key: ValueKey(task.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Theme.of(context).colorScheme.errorContainer,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: const Icon(Icons.delete_outline),
                      ),
                      onDismissed: (_) =>
                          _guard(() => Repo.instance.deleteTask(task.id)),
                      child: CheckboxListTile(
                        controlAffinity: ListTileControlAffinity.leading,
                        value: task.done,
                        onChanged: (v) => _guard(
                          () => Repo.instance.setTaskDone(task.id, v ?? false),
                        ),
                        title: Text(
                          task.title,
                          style: task.done
                              ? const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                )
                              : null,
                        ),
                        subtitle: Text(task.done
                            ? 'Done by ${widget.nameOf(task.doneBy)}'
                            : 'Added by ${widget.nameOf(task.createdBy)}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
