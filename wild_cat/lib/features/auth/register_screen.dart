import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/form_section_card.dart';
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
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

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
      final List<LookupOption> departments =
          await _organizationService.getDepartments();
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
    FocusScope.of(context).unfocus();
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
        backgroundColor: success ? AppColors.success : AppColors.danger,
        content: Text(
          success
              ? 'Registration successful. Please sign in.'
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
      appBar: AppBar(title: const Text('Create Account')),
      body: Consumer<AuthProvider>(
        builder: (BuildContext context, AuthProvider authProvider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // ── Personal Information ─────────────────────────────
                      FormSectionCard(
                        title: 'Personal Information',
                        subtitle: 'Tell us who you are',
                        icon: Icons.badge_outlined,
                        children: <Widget>[
                          TextFormField(
                            controller: _fullNameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator:
                                _requiredValidator('Please enter full name'),
                          ),
                          AppSpacing.gapLg,
                          TextFormField(
                            controller: _birthdayController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Birthday',
                              prefixIcon: Icon(Icons.cake_outlined),
                              suffixIcon: Icon(Icons.calendar_today_outlined),
                            ),
                            onTap: _pickBirthday,
                            validator:
                                _requiredValidator('Please select birthday'),
                          ),
                        ],
                      ),
                      AppSpacing.gapLg,

                      // ── Professional Information ─────────────────────────
                      FormSectionCard(
                        title: 'Professional Information',
                        subtitle: 'Your department and role',
                        icon: Icons.work_outline,
                        children: <Widget>[
                          if (_loadingDepartments)
                            const LinearProgressIndicator()
                          else ...<Widget>[
                            DropdownButtonFormField<int>(
                              initialValue: _selectedDepartmentId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Department',
                                prefixIcon: Icon(Icons.apartment_outlined),
                              ),
                              items: _departments
                                  .map(
                                    (LookupOption department) =>
                                        DropdownMenuItem<int>(
                                      value: department.id,
                                      child: Text(department.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: authProvider.isLoading
                                  ? null
                                  : (int? value) =>
                                      _handleDepartmentChanged(value),
                              validator: (int? value) {
                                if (value == null) {
                                  return 'Please select department';
                                }
                                return null;
                              },
                            ),
                            AppSpacing.gapLg,
                            if (_loadingPositions)
                              const LinearProgressIndicator()
                            else
                              DropdownButtonFormField<int>(
                                initialValue: _selectedPositionId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Position',
                                  prefixIcon: Icon(Icons.military_tech_outlined),
                                ),
                                items: _positions
                                    .map(
                                      (LookupOption position) =>
                                          DropdownMenuItem<int>(
                                        value: position.id,
                                        child: Text(position.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _selectedDepartmentId == null ||
                                        authProvider.isLoading
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
                            AppSpacing.gapSm,
                            Text(
                              _lookupError!,
                              style: const TextStyle(color: AppColors.danger),
                            ),
                          ],
                        ],
                      ),
                      AppSpacing.gapLg,

                      // ── Account Information ──────────────────────────────
                      FormSectionCard(
                        title: 'Account Information',
                        subtitle: 'Credentials used to sign in',
                        icon: Icons.lock_outline,
                        children: <Widget>[
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: _requiredValidator('Please enter email'),
                          ),
                          AppSpacing.gapLg,
                          TextFormField(
                            controller: _usernameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.alternate_email),
                            ),
                            validator:
                                _requiredValidator('Please enter username'),
                          ),
                          AppSpacing.gapLg,
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () => setState(() =>
                                    _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator:
                                _requiredValidator('Please enter password'),
                          ),
                          AppSpacing.gapLg,
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirm,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm),
                              ),
                            ),
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
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      ElevatedButton(
                        onPressed:
                            authProvider.isLoading || _loadingDepartments
                                ? null
                                : _register,
                        child: authProvider.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text('Create Account'),
                      ),
                      AppSpacing.gapSm,
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Already have an account? Sign in'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickBirthday() async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialDate: DateTime(2000),
    );

    if (selectedDate != null) {
      _birthdayController.text = selectedDate.toIso8601String().split('T').first;
    }
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
