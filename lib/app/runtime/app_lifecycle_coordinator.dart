import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/backup/backup_controller.dart';
import '../../features/dashboard/scan_controller.dart';
import '../../features/duplicates/contact_copy_controller.dart';

class AppLifecycleCoordinator extends StatefulWidget {
  final Widget child;

  const AppLifecycleCoordinator({required this.child, super.key});

  @override
  State<AppLifecycleCoordinator> createState() => _AppLifecycleCoordinatorState();
}

class _AppLifecycleCoordinatorState extends State<AppLifecycleCoordinator>
    with WidgetsBindingObserver {
  AppLifecycleState? _lastState;
  int _resumeGeneration = 0;
  bool _resumeInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _resumeGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_lastState == state) return;
    _lastState = state;
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _handleBackground();
      case AppLifecycleState.resumed:
        unawaited(_handleResume());
    }
  }

  void _handleBackground() {
    context.read<ScanController>().invalidateForLifecyclePause();
  }

  Future<void> _handleResume() async {
    if (_resumeInFlight) return;
    final generation = ++_resumeGeneration;
    _resumeInFlight = true;
    try {
      final scan = context.read<ScanController>();
      final backup = context.read<BackupController>();
      final copy = context.read<ContactCopyController>();
      await scan.refreshPermission();
      if (!mounted || generation != _resumeGeneration) return;
      backup.clearMergeValidation();
      if (copy.status != ContactCopyControllerStatus.idle) {
        copy.markExternalStateUnknown();
      }
    } finally {
      if (generation == _resumeGeneration) _resumeInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
