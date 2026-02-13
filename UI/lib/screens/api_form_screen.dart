import 'package:flutter/material.dart';
import '../widgets/api_form_widget.dart';

class ApiFormScreen extends StatelessWidget {
  const ApiFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Console'),
      ),
      body: const ApiFormWidget(),
    );
  }
}
