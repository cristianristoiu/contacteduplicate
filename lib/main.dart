import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/contact_duplicate_app.dart';
import 'core/theme/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ChangeNotifierProvider<ThemeProvider>(
      create: (_) => ThemeProvider(),
      child: const ContactDuplicateApp(),
    ),
  );
}
