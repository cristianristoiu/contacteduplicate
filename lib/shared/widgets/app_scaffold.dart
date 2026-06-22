import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.child,
    this.title,
    this.actions,
    this.bottomNavigationBar,
    super.key,
  });

  final String? title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title == null
          ? null
          : AppBar(
              title: Text(title!),
              actions: actions,
            ),
      body: SafeArea(
        child: child,
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
