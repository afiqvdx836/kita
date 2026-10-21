import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/repo.dart';

/// Shown until two people share a couple. One side creates a code, the other
/// enters it. The gate above switches to home as soon as the partner joins.
class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _code = TextEditingController();
  String? _myCode;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createCode() => _run(() async {
        final code = await Repo.instance.createInvite();
        setState(() => _myCode = code);
      });

  Future<void> _join() => _run(() async {
        if (_code.text.trim().length < 6) {
          throw 'Enter the 6-character code.';
        }
        await Repo.instance.joinCouple(_code.text);
      });

  Future<void> _copy() async {
    final code = _myCode;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(
      text: 'Join me on Kita! My code is $code (valid for 7 days).',
    ));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invite copied')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pair up'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => Repo.instance.signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Invite your partner', style: text.titleLarge),
          const SizedBox(height: 8),
          const Text('Create a code and send it to them. This screen opens '
              'your shared space as soon as they join.'),
          const SizedBox(height: 16),
          if (_myCode == null)
            FilledButton.icon(
              onPressed: _busy ? null : _createCode,
              icon: const Icon(Icons.favorite_outline),
              label: const Text('Create invite code'),
            )
          else
            Card(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    SelectableText(
                      _myCode!,
                      style: text.displaySmall?.copyWith(
                        letterSpacing: 6,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Valid for 7 days',
                        style: TextStyle(color: scheme.onPrimaryContainer)),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _copy,
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy invite'),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Waiting for your partner…'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Divider(),
          ),
          Text('Got a code?', style: text.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            decoration: const InputDecoration(
              labelText: 'Partner\'s code',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            onSubmitted: (_) => _join(),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _busy ? null : _join,
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}
