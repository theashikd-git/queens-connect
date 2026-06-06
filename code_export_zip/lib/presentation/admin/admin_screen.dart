// lib/presentation/admin/admin_screen.dart
// Separate admin login — creates new field staff accounts in Firebase

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hospital_field_app/core/theme/app_theme.dart';
import 'package:hospital_field_app/presentation/shared/widgets/common_widgets.dart';

// ─────────────────────────────────────────────────────────────────────
//  ADMIN CREDENTIALS — change these to your own secret values
// ─────────────────────────────────────────────────────────────────────
const String _adminEmail    = 'admin@queensconnect.com';
const String _adminPassword = 'Admin@9999';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  // ── Login state ──
  bool _isLoggedIn     = false;
  bool _isLoggingIn    = false;
  String? _loginError;
  final _emailLoginCtrl    = TextEditingController();
  final _passwordLoginCtrl = TextEditingController();
  bool _obscureLogin       = true;

  // ── Create user state ──
  bool _isCreating = false;
  String? _createError;
  String? _createSuccess;
  final _formKey        = GlobalKey<FormState>();
  final _nameCtrl       = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  bool _obscureCreate   = true;
  String _selectedRole  = 'user';

  // ── Staff list ──
  List<Map<String, dynamic>> _staffList = [];
  bool _loadingStaff = false;

  @override
  void dispose() {
    _emailLoginCtrl.dispose();
    _passwordLoginCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────
  //  ADMIN LOGIN
  // ─────────────────────────────────────────

  Future<void> _adminLogin() async {
    if (_emailLoginCtrl.text.trim() != _adminEmail ||
        _passwordLoginCtrl.text != _adminPassword) {
      setState(() => _loginError = 'Invalid admin credentials.');
      return;
    }

    setState(() {
      _isLoggingIn = true;
      _loginError  = null;
    });

    await Future.delayed(const Duration(milliseconds: 800));

    setState(() {
      _isLoggingIn = false;
      _isLoggedIn  = true;
    });

    _loadStaffList();
  }

  // ─────────────────────────────────────────
  //  LOAD EXISTING STAFF
  // ─────────────────────────────────────────

  Future<void> _loadStaffList() async {
    setState(() => _loadingStaff = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('name')
          .get();

      setState(() {
        _staffList = snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
        _loadingStaff = false;
      });
    } catch (e) {
      setState(() => _loadingStaff = false);
    }
  }

  // ─────────────────────────────────────────
  //  CREATE NEW STAFF USER
  // ─────────────────────────────────────────

  Future<void> _createStaff() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreating   = true;
      _createError  = null;
      _createSuccess = null;
    });

    try {
      // 1. Create Firebase Auth account for the new staff member
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      final uid = credential.user!.uid;

      // 2. Save their profile to Firestore users collection
      final createdName = _nameCtrl.text.trim();
      final createdRole = _selectedRole;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
        'name'       : createdName,
        'email'      : _emailCtrl.text.trim(),
        'role'       : createdRole,
        'created_at' : FieldValue.serverTimestamp(),
      });

      // 3. Clear form and show success
      _nameCtrl.clear();
      _emailCtrl.clear();
      _passwordCtrl.clear();
      setState(() => _selectedRole = 'user');

      setState(() {
        _isCreating    = false;
        _createSuccess =
            '✅ ${createdRole == 'manager' ? 'Manager' : 'Staff'} "$createdName" created successfully!';
      });

      // Reload staff list
      _loadStaffList();

      // Show success dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: AppTheme.successGreen, size: 36),
                ),
                const SizedBox(height: 16),
                const Text('Staff Created!',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                Text(
                  'Account created successfully.\nThey can now log in to the app.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Failed to create account.';
      if (e.code == 'email-already-in-use') {
        msg = 'This email is already registered.';
      } else if (e.code == 'weak-password') {
        msg = 'Password is too weak. Use at least 6 characters.';
      } else if (e.code == 'invalid-email') {
        msg = 'Invalid email address.';
      }
      setState(() {
        _isCreating  = false;
        _createError = msg;
      });
    } catch (e) {
      setState(() {
        _isCreating  = false;
        _createError = 'Error: ${e.toString()}';
      });
    }
  }

  // ─────────────────────────────────────────
  //  DELETE STAFF
  // ─────────────────────────────────────────

  Future<void> _deleteStaff(String uid, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Staff Member'),
        content: Text(
            'Are you sure you want to remove $name from the system?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Remove from Firestore (Auth account stays — Firebase limitation)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .delete();

      _loadStaffList();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name removed successfully.'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove staff member.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          if (_isLoggedIn)
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => setState(() {
                _isLoggedIn = false;
                _staffList  = [];
              }),
              tooltip: 'Admin Logout',
            ),
        ],
      ),
      body: _isLoggedIn ? _buildAdminPanel() : _buildLoginScreen(),
    );
  }

  // ─────────────────────────────────────────
  //  LOGIN SCREEN
  // ─────────────────────────────────────────

  Widget _buildLoginScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryBlue, AppTheme.accentTeal],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: Colors.white, size: 40),
          ),
          const SizedBox(height: 16),
          const Text('Admin Panel',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          const Text('Restricted access only',
              style:
                  TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 40),

          // Login card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Column(
              children: [
                TextFormField(
                  controller: _emailLoginCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Admin Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordLoginCtrl,
                  obscureText: _obscureLogin,
                  decoration: InputDecoration(
                    labelText: 'Admin Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureLogin
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscureLogin = !_obscureLogin),
                    ),
                  ),
                ),

                if (_loginError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppTheme.errorRed, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_loginError!,
                              style: const TextStyle(
                                  color: AppTheme.errorRed, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoggingIn ? null : _adminLogin,
                    child: _isLoggingIn
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Login as Admin'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  //  ADMIN PANEL
  // ─────────────────────────────────────────

  Widget _buildAdminPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Welcome banner ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryBlue, AppTheme.primaryBlueDark],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.admin_panel_settings_rounded,
                    color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Admin Panel',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      const Text('Create and manage field staff accounts',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text(
                        '${_staffList.length} account(s) loaded',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Create new staff card ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Add New Field Staff',
                    subtitle: 'Create a login account for a new marketing executive',
                  ),
                  const SizedBox(height: 20),

                  // Full Name
                  TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'e.g. Rahim Uddin',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Full name is required'
                        : null,
                  ),
                  const SizedBox(height: 14),

                  // Email
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'e.g. rahim@queensconnect.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Email is required';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Role
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      prefixIcon: Icon(Icons.work_outline),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'user', child: Text('Field Staff')),
                      DropdownMenuItem(value: 'manager', child: Text('Manager')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedRole = value);
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Password
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscureCreate,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Minimum 6 characters',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureCreate
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(
                            () => _obscureCreate = !_obscureCreate),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Password is required';
                      }
                      if (v.length < 6) {
                        return 'Minimum 6 characters';
                      }
                      return null;
                    },
                  ),

                  // Error
                  if (_createError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppTheme.errorRed, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_createError!,
                                style: const TextStyle(
                                    color: AppTheme.errorRed,
                                    fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isCreating ? null : _createStaff,
                      icon: _isCreating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add_rounded),
                      label: Text(
                        _isCreating
                            ? 'Creating Account...'
                            : 'Create Staff Account',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Staff list ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: SectionHeader(
                        title: 'Current Field Staff',
                        subtitle: 'All active marketing executives',
                      ),
                    ),
                    IconButton(
                      onPressed: _loadStaffList,
                      icon: const Icon(Icons.refresh_rounded,
                          color: AppTheme.primaryBlue),
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_loadingStaff)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryBlue),
                    ),
                  )
                else if (_staffList.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No staff members yet.\nAdd one above.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppTheme.textTertiary, fontSize: 14),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _staffList.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final staff = _staffList[index];
                      final name  = staff['name'] ?? '';
                      final email = staff['email'] ?? '';
                      final role  = staff['role'] ?? 'user';
                      final uid   = staff['id'] ?? '';

                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.primaryBlue.withValues(alpha: 0.1),
                          child: Text(
                            name.isNotEmpty
                                ? name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppTheme.textPrimary)),
                        subtitle: Text('$email • ${role == 'manager' ? 'Manager' : 'Field Staff'}',
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: AppTheme.errorRed, size: 20),
                          onPressed: () => _deleteStaff(uid, name),
                          tooltip: 'Remove staff',
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}