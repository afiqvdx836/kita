import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_supabaseUrl.isEmpty || _supabaseKey.isEmpty) {
    throw StateError(
      'Missing Supabase config. Run with --dart-define-from-file=env.json',
    );
  }

  await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseKey);
  runApp(const KitaApp());
}
