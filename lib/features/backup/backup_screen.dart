import 'package:flutter/material.dart';

import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_scaffold.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Backup',
      child: AppEmptyState(
        icon: Icons.backup_outlined,
        title: 'Nu exista copii de rezerva',
        description:
            'Aplicatia va crea o copie de rezerva locala inainte de orice modificare a contactelor.',
      ),
    );
  }
}
