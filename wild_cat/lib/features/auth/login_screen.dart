import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final AuthProvider authProvider = context.read<AuthProvider>();
    final bool success = await authProvider.login(
      _identifierController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) {
      return;
    }

    final String message = success
        ? 'Login successful'
        : (authProvider.errorMessage ?? 'Login failed');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Consumer<AuthProvider>(
        builder: (BuildContext context, AuthProvider authProvider, Widget? _) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: <Widget>[
                  TextFormField(
                    controller: _identifierController,
                    decoration: const InputDecoration(
                      labelText: 'Email or Username',
                    ),
                    validator: (String? value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter email or username';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  if (authProvider.isLoading)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton(
                      onPressed: _onLoginPressed,
                      child: const Text('Login'),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
