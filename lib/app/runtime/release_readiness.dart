import '../../core/theme/theme_provider.dart';
import '../../features/backup/backup_controller.dart';
import '../../features/dashboard/scan_controller.dart';
import '../../features/duplicates/merge_operation_controller.dart';
import '../../features/history/history_controller.dart';
import '../../features/restore/restore_controller.dart';
import 'operation_coordinator.dart';

enum ReleaseReadinessBlocker {
  operationInProgress,
  criticalMutationInProgress,
  scanInProgress,
  scanResultsStale,
  mergeInProgress,
  mergeNeedsReconcile,
  mergeHistoryNotPersisted,
  restoreInProgress,
  restoreNeedsReconcile,
  restoreHistoryNotPersisted,
  backupStateUnavailable,
  backupOperationInProgress,
  backupIntegrityUnavailable,
  historyUnavailable,
  backupProtectionUnknown,
  themePreferenceUnavailable,
}

class ReleaseReadinessSnapshot {
  final Set<ReleaseReadinessBlocker> blockers;

  const ReleaseReadinessSnapshot(this.blockers);

  bool get isReadyForDeviceValidation => blockers.isEmpty;
  int get blockerCount => blockers.length;

  bool contains(ReleaseReadinessBlocker blocker) => blockers.contains(blocker);
}

class ReleaseReadinessEvaluator {
  const ReleaseReadinessEvaluator();

  ReleaseReadinessSnapshot evaluate({
    required OperationCoordinator coordinator,
    required ScanController scan,
    required MergeOperationController merge,
    required RestoreController restore,
    required BackupController backup,
    required HistoryController history,
    required ThemeProvider theme,
  }) {
    final blockers = <ReleaseReadinessBlocker>{};

    if (coordinator.isBusy) {
      blockers.add(ReleaseReadinessBlocker.operationInProgress);
    }
    if (coordinator.isCritical) {
      blockers.add(ReleaseReadinessBlocker.criticalMutationInProgress);
    }
    if (scan.isScanning) {
      blockers.add(ReleaseReadinessBlocker.scanInProgress);
    }
    if (scan.resultsStale) {
      blockers.add(ReleaseReadinessBlocker.scanResultsStale);
    }
    if (merge.isRunning) {
      blockers.add(ReleaseReadinessBlocker.mergeInProgress);
    }
    if (merge.requiresReconcile) {
      blockers.add(ReleaseReadinessBlocker.mergeNeedsReconcile);
    }
    if (merge.historyWriteFailed) {
      blockers.add(ReleaseReadinessBlocker.mergeHistoryNotPersisted);
    }
    if (restore.isBusy) {
      blockers.add(ReleaseReadinessBlocker.restoreInProgress);
    }
    if (restore.requiresReconcile) {
      blockers.add(ReleaseReadinessBlocker.restoreNeedsReconcile);
    }
    if (restore.historyWriteFailed) {
      blockers.add(ReleaseReadinessBlocker.restoreHistoryNotPersisted);
    }
    if (backup.status == BackupStatus.error ||
        backup.status == BackupStatus.permissionDenied) {
      blockers.add(ReleaseReadinessBlocker.backupStateUnavailable);
    }
    if (backup.isBusy) {
      blockers.add(ReleaseReadinessBlocker.backupOperationInProgress);
    }
    if (backup.backups.any((candidate) => !candidate.isValid)) {
      blockers.add(ReleaseReadinessBlocker.backupIntegrityUnavailable);
    }
    if (history.status == HistoryControllerStatus.error) {
      blockers.add(ReleaseReadinessBlocker.historyUnavailable);
    }
    if (!history.canEvaluateBackupProtection) {
      blockers.add(ReleaseReadinessBlocker.backupProtectionUnknown);
    }
    if (theme.persistenceStatus == ThemePersistenceStatus.error) {
      blockers.add(ReleaseReadinessBlocker.themePreferenceUnavailable);
    }

    return ReleaseReadinessSnapshot(
      Set<ReleaseReadinessBlocker>.unmodifiable(blockers),
    );
  }

  String label(ReleaseReadinessBlocker blocker) => switch (blocker) {
        ReleaseReadinessBlocker.operationInProgress =>
          'Exista o operatie locala in curs.',
        ReleaseReadinessBlocker.criticalMutationInProgress =>
          'Agenda este intr-o faza critica de modificare.',
        ReleaseReadinessBlocker.scanInProgress => 'Scanarea este in curs.',
        ReleaseReadinessBlocker.scanResultsStale =>
          'Rezultatele scanarii sunt invechite.',
        ReleaseReadinessBlocker.mergeInProgress => 'Fuziunea este in curs.',
        ReleaseReadinessBlocker.mergeNeedsReconcile =>
          'O fuziune necesita reconcilierea agendei.',
        ReleaseReadinessBlocker.mergeHistoryNotPersisted =>
          'Rezultatul unei fuziuni nu este inca persistat in istoric.',
        ReleaseReadinessBlocker.restoreInProgress =>
          'Restaurarea este in curs.',
        ReleaseReadinessBlocker.restoreNeedsReconcile =>
          'O restaurare necesita reconcilierea agendei.',
        ReleaseReadinessBlocker.restoreHistoryNotPersisted =>
          'Rezultatul unei restaurari nu este inca persistat in istoric.',
        ReleaseReadinessBlocker.backupStateUnavailable =>
          'Starea serviciului de backup nu este sanatoasa.',
        ReleaseReadinessBlocker.backupOperationInProgress =>
          'O operatie de backup este in curs.',
        ReleaseReadinessBlocker.backupIntegrityUnavailable =>
          'Exista un backup local care nu trece verificarea de integritate.',
        ReleaseReadinessBlocker.historyUnavailable =>
          'Istoricul operational nu poate fi citit.',
        ReleaseReadinessBlocker.backupProtectionUnknown =>
          'Protectia backupurilor necesare pentru undo nu poate fi demonstrata.',
        ReleaseReadinessBlocker.themePreferenceUnavailable =>
          'Preferinta de tema nu poate fi persistata.',
      };
}
