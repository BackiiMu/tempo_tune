import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/storage/app_state.dart';
import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(await SharedPreferences.getInstance());
  runApp(
    ProviderScope(
      overrides: [appProvider.overrideWithValue(state)],
      child: const TempoTuneApp(),
    ),
  );
}
