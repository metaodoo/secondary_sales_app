import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/core/constants.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

/// Shown when the server will not enumerate its databases. This is the normal
/// response from Odoo.sh and any instance running with `list_db = False`, not an
/// error the user needs to resolve — those servers host a single database and
/// select it from the hostname.
const String _kDbListUnavailable =
    'This server does not publish a database list (normal for Odoo.sh). '
    'Leave the database field blank — the server will select its own.';

class ConnectionSetupScreen extends StatefulWidget {
  const ConnectionSetupScreen({super.key});

  @override
  State<ConnectionSetupScreen> createState() => _ConnectionSetupScreenState();
}

class _ConnectionSetupScreenState extends State<ConnectionSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController(text: AppConstants.baseUrl);
  final _dbController = TextEditingController(text: AppConstants.dbName);
  List<String> _databases = [];
  bool _isLoadingDatabases = false;
  bool _isConfirming = false;
  String? _error;

  @override
  void dispose() {
    _serverController.dispose();
    _dbController.dispose();
    super.dispose();
  }

  Future<void> _loadDatabases() async {
    final serverUrl = _serverController.text.trim();
    if (serverUrl.isEmpty) {
      setState(() => _error = 'Server URL is required.');
      return;
    }

    setState(() {
      _isLoadingDatabases = true;
      _error = null;
    });

    try {
      final databases = await context.read<AuthProvider>().fetchDatabases(
        serverUrl,
      );
      if (!mounted) return;
      setState(() {
        _databases = databases;
        if (databases.isNotEmpty && _dbController.text.trim().isEmpty) {
          _dbController.text = databases.first;
        }
        if (databases.isEmpty) {
          _error = _kDbListUnavailable;
        }
      });
    } catch (e) {
      // Servers with the database manager disabled — every Odoo.sh build, and
      // any instance run with list_db = False — reject this call outright. That
      // is not a setup failure: they host exactly one database and resolve it
      // from the hostname, so the field can simply be left blank.
      if (!mounted) return;
      setState(() {
        _databases = [];
        _error = '$_kDbListUnavailable\n\nDetails: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingDatabases = false);
      }
    }
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isConfirming = true;
      _error = null;
    });

    try {
      // An empty database is valid and means "let the server resolve it".
      await context.read<AuthProvider>().setupConnection(
        baseUrl: _serverController.text,
        dbName: _dbController.text.trim(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isConfirming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isLoadingDatabases || _isConfirming;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    'Connect Server',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter your Odoo server URL. Tap Load to pick a database, or '
                    'leave it blank to use the server default.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderSoft),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Server',
                            style: TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _serverController,
                            enabled: !isBusy,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.next,
                            decoration: _inputDecoration(
                              hintText: 'http://127.0.0.1:8069',
                            ),
                            onChanged: (_) {
                              setState(() {
                                _databases = [];
                                _error = null;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Server URL is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                // Free text rather than a dropdown: servers with
                                // the database manager disabled return no list to
                                // populate one, and a dropdown offers no way to
                                // proceed without an item. Optional by design.
                                child: TextFormField(
                                  controller: _dbController,
                                  enabled: !isBusy,
                                  textInputAction: TextInputAction.done,
                                  decoration: _inputDecoration(
                                    hintText: 'Database (optional)',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                height: 52,
                                child: OutlinedButton(
                                  onPressed: isBusy ? null : _loadDatabases,
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isLoadingDatabases
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Load'),
                                ),
                              ),
                            ],
                          ),
                          if (_databases.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _databases
                                  .map(
                                    (database) => ActionChip(
                                      label: Text(database),
                                      onPressed: isBusy
                                          ? null
                                          : () => setState(
                                              () => _dbController.text =
                                                  database,
                                            ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            ErrorPanel(_error!),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: isBusy ? null : _confirm,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isConfirming
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Confirm',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      fillColor: Colors.white,
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderSoft),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }
}
