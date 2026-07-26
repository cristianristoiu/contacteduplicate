import 'package:flutter/material.dart';

import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_scaffold.dart';

class DuplicatesScreen extends StatelessWidget {
  const DuplicatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Duplicate',
      child: AppEmptyState(
        icon: Icons.people_alt_outlined,
        title: 'Nu exista rezultate de afisat',
        description:
            'Porneste o scanare din Dashboard pentru a identifica grupurile de contacte duplicate.',
      ),
    );
  }
}
