import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../notes/notes_screen.dart';
import '../tasks/tasks_screen.dart';
import 'home_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.me,
    required this.partner,
    required this.coupleId,
  });

  final Profile me;
  final Profile partner;
  final String coupleId;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  /// Maps a user id to a first name for "by …" labels.
  String nameOf(String? id) {
    if (id == widget.me.id) return 'You';
    if (id == widget.partner.id) return widget.partner.label;
    return 'Someone';
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(me: widget.me, partner: widget.partner, coupleId: widget.coupleId),
      NotesScreen(coupleId: widget.coupleId, nameOf: nameOf),
      TasksScreen(coupleId: widget.coupleId, nameOf: nameOf),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Us',
          ),
          NavigationDestination(
            icon: Icon(Icons.sticky_note_2_outlined),
            selectedIcon: Icon(Icons.sticky_note_2),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Tasks',
          ),
        ],
      ),
    );
  }
}
