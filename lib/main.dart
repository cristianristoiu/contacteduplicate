import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'app/contact_duplicate_app.dart';
import 'core/backup/contact_backup_service.dart';
import 'core/contacts/contacts_scan_service.dart';
import 'core/theme/theme_provider.dart';
import 'features/backup/backup_controller.dart';
import 'features/dashboard/scan_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider<ScanController>(
          create: (_) => ScanController(NativeContactsScanService()),
        ),
        ChangeNotifierProvider<BackupController>(
          create: (_) => BackupController(
            EncryptedContactBackupService(),
          ),
        ),
      ],
      child: const ContactDuplicateApp(),
    ),
  );
}
