import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'app/contact_duplicate_app.dart';
import 'app/runtime/app_lifecycle_coordinator.dart';
import 'core/backup/contact_backup_service.dart';
import 'core/backup/protected_contact_backup_service.dart';
import 'core/contacts/contact_copy_service.dart';
import 'core/contacts/contacts_scan_service.dart';
import 'core/theme/theme_provider.dart';
import 'features/backup/backup_controller.dart';
import 'features/dashboard/scan_controller.dart';
import 'features/duplicates/contact_copy_controller.dart';

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
          create: (_) {
            final controller = BackupController(
              ProtectedContactBackupService(
                delegate: EncryptedContactBackupService(),
              ),
            );
            unawaited(controller.load());
            return controller;
          },
        ),
        ChangeNotifierProvider<ContactCopyController>(
          create: (_) => ContactCopyController(
            NativeContactCopyService(),
          ),
        ),
      ],
      child: const AppLifecycleCoordinator(
        child: ContactDuplicateApp(),
      ),
    ),
  );
}
