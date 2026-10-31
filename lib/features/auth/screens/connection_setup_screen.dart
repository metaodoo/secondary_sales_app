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
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
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
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: canPop
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Server Connection',
                style: TextStyle(
                  color: AppColors.primaryStrong,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              centerTitle: true,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: AppColors.borderMuted, height: 1),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (canPop && AppConstants.hasSavedConnection) ...[
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primaryTint),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryTint,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.cloud_done_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Current Connection',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryStrong,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AppConstants.baseUrl,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (AppConstants.dbName.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Database: ${AppConstants.dbName}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!canPop) ...[
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
                  ],
                  const Text(
                    'Enter your Odoo server URL. Tap Load to pick a database, or '
                    'leave it blank to use the server default.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
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
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isBusy
                                      ? null
                                      : () {
                                          setState(() {
                                            _serverController.text =
                                                AppConstants.prodBaseUrl;
                                            _dbController.text =
                                                AppConstants.prodDbName;
                                            _databases = [];
                                            _error = null;
                                          });
                                        },
                                  icon: const Icon(Icons.cloud_done_outlined, size: 16),
                                  label: const Text('Production'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isBusy
                                      ? null
                                      : () {
                                          setState(() {
                                            _serverController.text =
                                                AppConstants.uatBaseUrl;
                                            _dbController.text =
                                                AppConstants.uatDbName;
                                            _databases = [];
                                            _error = null;
                                          });
                                        },
                                  icon: const Icon(Icons.science_outlined, size: 16),
                                  label: const Text('Field UAT'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
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
                              hintText: AppConstants.defaultBaseUrl,
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
                          const SizedBox(height: 16),
                          const Text(
                            'Database',
                            style: TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                    hintText: AppConstants.defaultDbName,
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
