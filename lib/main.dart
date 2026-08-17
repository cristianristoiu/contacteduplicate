import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'app/contact_duplicate_app.dart';
import 'app/runtime/app_lifecycle_coordinator.dart';
import 'app/runtime/operation_coordinator.dart';
import 'core/backup/contact_backup_service.dart';
import 'core/backup/protected_contact_backup_service.dart';
import 'core/contacts/contact_copy_service.dart';
import 'core/contacts/contacts_scan_service.dart';
import 'core/theme/theme_provider.dart';
import 'features/backup/backup_controller.dart';
import 'features/dashboard/scan_controller.dart';
import 'features/duplicates/contact_copy_controller.dart';
import 'features/duplicates/merge_engine_service.dart';
import 'features/duplicates/merge_operation_controller.dart';
import 'features/duplicates/native_merge_contact_gateway.dart';
import 'features/duplicates/strict_merge_plan_validator.dart';
import 'features/history/history_controller.dart';
import 'features/history/operation_history.dart';
import 'features/restore/restore_controller.dart';
import 'features/restore/restore_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<OperationCoordinator>(
          create: (_) => OperationCoordinator(),
        ),
        Provider<ContactBackupService>(
          create: (_) => ProtectedContactBackupService(
            delegate: EncryptedContactBackupService(),
          ),
        ),
        Provider<OperationHistoryRepository>(
          create: (_) => PreferencesOperationHistoryRepository(),
        ),
        Provider<MergeContactGateway>(
          create: (_) => NativeMergeContactGateway(),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider<ScanController>(
          create: (context) => ScanController(
            NativeContactsScanService(),
            operationCoordinator: context.read<OperationCoordinator>(),
          ),
        ),
        ChangeNotifierProvider<BackupController>(
          create: (context) {
            final controller = BackupController(
              context.read<ContactBackupService>(),
            );
            unawaited(controller.load());
            return controller;
          },
        ),
        Provider<MergeEngineService>(
          create: (context) => MergeEngineService(
            gateway: context.read<MergeContactGateway>(),
            backupController: context.read<BackupController>(),
            validator: const StrictMergePlanValidator(),
          ),
        ),
        Provider<ContactRestoreService>(
          create: (context) => ContactRestoreService(
            backupService: context.read<ContactBackupService>(),
          ),
        ),
        ChangeNotifierProvider<MergeOperationController>(
          create: (context) => MergeOperationController(
            engine: context.read<MergeEngineService>(),
            gateway: context.read<MergeContactGateway>(),
            history: context.read<OperationHistoryRepository>(),
            scanController: context.read<ScanController>(),
            operationCoordinator: context.read<OperationCoordinator>(),
          ),
        ),
        ChangeNotifierProvider<RestoreController>(
          create: (context) => RestoreController(
            service: context.read<ContactRestoreService>(),
            history: context.read<OperationHistoryRepository>(),
            scanController: context.read<ScanController>(),
            operationCoordinator: context.read<OperationCoordinator>(),
          ),
        ),
        ChangeNotifierProvider<HistoryController>(
          create: (context) {
            final controller = HistoryController(
              repository: context.read<OperationHistoryRepository>(),
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
