import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/organization_service.dart';
import '../profile/models/lookup_option.dart';
import 'auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final OrganizationService _organizationService = OrganizationService();

  List<LookupOption> _departments = <LookupOption>[];
  List<LookupOption> _positions = <LookupOption>[];
  int? _selectedDepartmentId;
  int? _selectedPositionId;
  bool _loadingDepartments = true;
  bool _loadingPositions = false;
  String? _lookupError;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _birthdayController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    try {
      final List<LookupOption> departments = await _organizationService.getDepartments();
      if (!mounted) {
        return;
      }
      setState(() {
        _departments = departments;
        _loadingDepartments = false;
        _lookupError = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingDepartments = false;
        _lookupError = 'Failed to load departments.';
      });
    }
  }

  Future<void> _handleDepartmentChanged(int? departmentId) async {
    setState(() {
      _selectedDepartmentId = departmentId;
      _selectedPositionId = null;
      _positions = <LookupOption>[];
      _lookupError = null;
      _loadingPositions = departmentId != null;
    });

    if (departmentId == null) {
      return;
    }

    try {
      final List<LookupOption> positions =
          await _organizationService.getPositions(departmentId);
      if (!mounted) {
        return;
      }
      setState(() {
        _positions = positions;
        _loadingPositions = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingPositions = false;
        _lookupError = 'Failed to load positions.';
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final int? departmentId = _selectedDepartmentId;
    final int? positionId = _selectedPositionId;
    if (departmentId == null || positionId == null) {
      return;
    }

    final AuthProvider authProvider = context.read<AuthProvider>();
    final bool success = await authProvider.register(<String, dynamic>{
      'full_name': _fullNameController.text.trim(),
      'username': _usernameController.text.trim(),
      'email': _emailController.text.trim(),
      'birthday': _birthdayController.text.trim(),
      'department_id': departmentId,
      'position_id': positionId,
      'password': _passwordController.text,
      'confirm_password': _confirmPasswordController.text,
    });

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Registration successful. Please login.'
              : (authProvider.errorMessage ?? 'Registration failed'),
        ),
      ),
    );

    if (success) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Consumer<AuthProvider>(
        builder: (BuildContext context, AuthProvider authProvider, Widget? _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                    validator: _requiredValidator('Please enter full name'),
                  ),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: _requiredValidator('Please enter email'),
                  ),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: 'Username'),
                    validator: _requiredValidator('Please enter username'),
                  ),
                  TextFormField(
                    controller: _birthdayController,
                    decoration: const InputDecoration(labelText: 'Birthday'),
                    readOnly: true,
                    onTap: () async {
                      final DateTime? selectedDate = await showDatePicker(
                        context: context,
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                        initialDate: DateTime(2000),
                      );

                      if (selectedDate != null) {
                        _birthdayController.text =
                            selectedDate.toIso8601String().split('T').first;
                      }
                    },
                    validator: _requiredValidator('Please select birthday'),
                  ),
                  const SizedBox(height: 16),
                  if (_loadingDepartments)
                    const LinearProgressIndicator()
                  else ...<Widget>[
                    DropdownButtonFormField<int>(
                      initialValue: _selectedDepartmentId,
                      decoration: const InputDecoration(labelText: 'Department'),
                      items: _departments
                          .map(
                            (LookupOption department) => DropdownMenuItem<int>(
                              value: department.id,
                              child: Text(department.name),
                            ),
                          )
                          .toList(),
                      onChanged: authProvider.isLoading
                          ? null
                          : (int? value) => _handleDepartmentChanged(value),
                      validator: (int? value) {
                        if (value == null) {
                          return 'Please select department';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_loadingPositions)
                      const LinearProgressIndicator()
                    else
                      DropdownButtonFormField<int>(
                        initialValue: _selectedPositionId,
                        decoration: const InputDecoration(labelText: 'Position'),
                        items: _positions
                            .map(
                              (LookupOption position) => DropdownMenuItem<int>(
                                value: position.id,
                                child: Text(position.name),
                              ),
                            )
                            .toList(),
                        onChanged: _selectedDepartmentId == null || authProvider.isLoading
                            ? null
                            : (int? value) {
                                setState(() {
                                  _selectedPositionId = value;
                                });
                              },
                        validator: (int? value) {
                          if (value == null) {
                            return 'Please select position';
                          }
                          return null;
                        },
                      ),
                  ],
                  if (_lookupError != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      _lookupError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: _requiredValidator('Please enter password'),
                  ),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: const InputDecoration(labelText: 'Confirm Password'),
                    obscureText: true,
                    validator: (String? value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  if (authProvider.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton(
                      onPressed: _loadingDepartments || _loadingPositions ? null : _register,
                      child: const Text('Register'),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  FormFieldValidator<String> _requiredValidator(String message) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) {
        return message;
      }
      return null;
    };
  }
}
