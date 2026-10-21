import 'package:flutter/material.dart';

import '../../core/days.dart';
import '../../core/stream_view.dart';
import '../../data/models.dart';
import '../../data/repo.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.me,
    required this.partner,
    required this.coupleId,
  });

  final Profile me;
  final Profile partner;
  final String coupleId;

  Future<void> _pickDate(BuildContext context, DateTime? current) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: 'When did you get together?',
    );
    if (picked == null) return;
    try {
      await Repo.instance.setTogetherSince(coupleId, picked);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _confirmUnpair(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpair?'),
        content: Text('You will leave your shared space with ${partner.label}. '
            'Your notes and tasks stay with them.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unpair'),
          ),
        ],
      ),
    );
    if (ok == true) await Repo.instance.leaveCouple();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('${me.label} & ${partner.label}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'signout') Repo.instance.signOut();
              if (v == 'unpair') _confirmUnpair(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'signout', child: Text('Sign out')),
              PopupMenuItem(value: 'unpair', child: Text('Unpair')),
            ],
          ),
        ],
      ),
      body: StreamView<Couple?>(
        create: () => Repo.instance.watchCouple(coupleId),
        builder: (context, snap) {
          final since = snap.data?.togetherSince;
          if (snap.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (since == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite, size: 56, color: scheme.primary),
                    const SizedBox(height: 16),
                    Text('When did your story start?',
                        style: text.titleLarge, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => _pickDate(context, null),
                      child: const Text('Set the date'),
                    ),
                  ],
                ),
              ),
            );
          }

          final today = DateTime.now();
          final days = daysTogether(since, today);
          final next = nextMilestone(since, today);

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 24),
              Icon(Icons.favorite, size: 40, color: scheme.primary),
              const SizedBox(height: 8),
              Text(
                '$days',
                style: text.displayLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              Text(days == 1 ? 'day together' : 'days together',
                  style: text.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => _pickDate(context, since),
                child: Text('Since ${formatDate(since)}'),
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.celebration_outlined),
                  title: Text('Day ${next.day}'),
                  subtitle: Text(next.inDays == 1
                      ? 'Tomorrow'
                      : 'In ${next.inDays} days'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
