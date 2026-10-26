import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/constants.dart';
import 'core/config/env.dart';
import 'core/settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettingsStore.instance.load();

  if (!AppEnv.isConfigured) {
    runApp(const IzicardApp(configurationError: true));
    return;
  }

  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    anonKey: AppEnv.supabaseAnonKey,
    postgrestOptions: PostgrestClientOptions(
      schema: AppConstants.nfcSchema,
    ),
  );

  runApp(const IzicardApp());
}
