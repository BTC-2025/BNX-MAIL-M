import 'package:flutter/material.dart';
import '../../../core/widgets/compose_dialog.dart';

class ComposeScreen extends StatelessWidget {
  const ComposeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: ComposeDialog());
  }
}
