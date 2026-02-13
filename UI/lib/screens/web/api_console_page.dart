import 'package:flutter/material.dart';
import '../../widgets/api_form_widget.dart';

class ApiConsolePage extends StatelessWidget {
  const ApiConsolePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: const ApiFormWidget(embedded: true),
        ),
      ),
    );
  }
}
