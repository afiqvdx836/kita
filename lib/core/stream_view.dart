import 'package:flutter/widgets.dart';

/// A StreamBuilder that subscribes once per widget lifetime, so parent
/// rebuilds (tab switches, auth token refreshes) don't open new realtime
/// channels. Give it a new [Key] to resubscribe.
class StreamView<T> extends StatefulWidget {
  const StreamView({super.key, required this.create, required this.builder});

  final Stream<T> Function() create;
  final AsyncWidgetBuilder<T> builder;

  @override
  State<StreamView<T>> createState() => _StreamViewState<T>();
}

class _StreamViewState<T> extends State<StreamView<T>> {
  late final Stream<T> _stream = widget.create();

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<T>(stream: _stream, builder: widget.builder);
}
