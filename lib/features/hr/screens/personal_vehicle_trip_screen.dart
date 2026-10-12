import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/widgets/app_camera_capture_dialog.dart';
import 'package:secondary_sales/core/services/media_storage_service.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/util/dialog_helper.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/hr/expense_provider.dart';

class PersonalVehicleTripScreen extends StatelessWidget {
  const PersonalVehicleTripScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ExpenseProvider(context.read<AuthProvider>()),
      child: const _PersonalVehicleTripContent(),
    );
  }
}

class _PersonalVehicleTripContent extends StatefulWidget {
  const _PersonalVehicleTripContent();

  @override
  State<_PersonalVehicleTripContent> createState() => _PersonalVehicleTripContentState();
}

class _PersonalVehicleTripContentState extends State<_PersonalVehicleTripContent> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _startKmController = TextEditingController();
  final _endKmController = TextEditingController();
  final _totalKmController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  File? _startPhotoFile;
  String? _startPhotoBase64;
  File? _endPhotoFile;
  String? _endPhotoBase64;

  Map<String, dynamic>? _vehicleCategory;
  Map<String, dynamic>? _activeTrip;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final provider = context.read<ExpenseProvider>();
    await Future.wait([
      provider.fetchCategories(),
      provider.fetchDrafts(),
    ]);

    if (!mounted) return;

    _vehicleCategory = provider.categories.cast<Map<String, dynamic>?>().firstWhere(
      (c) => c?['expense_allowance_type'] == 'personal_vehicle_mileage_rate_card',
      orElse: () => null,
    );

    final active = provider.drafts.cast<Map<String, dynamic>?>().firstWhere(
      (d) => d?['is_personal_vehicle'] == true,
      orElse: () => null,
    );

    setState(() {
      _activeTrip = active;
      if (active != null) {
        _titleController.text = active['title'] ?? 'Personal Vehicle Travel';
        final start = (active['odometer_day_start'] as num?)?.toDouble() ?? 0.0;
        _startKmController.text = start > 0 ? start.toStringAsFixed(1) : '';
        _notesController.text = active['description'] ?? '';
      } else {
        _titleController.text = 'Personal Vehicle Travel';
        _startKmController.clear();
        _endKmController.clear();
        _totalKmController.clear();
        _amountController.clear();
        _notesController.clear();
        _startPhotoFile = null;
        _startPhotoBase64 = null;
        _endPhotoFile = null;
        _endPhotoBase64 = null;
      }
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _startKmController.dispose();
    _endKmController.dispose();
    _totalKmController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isEndingTrip => _activeTrip != null;
  double? get _ratePerKm => (_vehicleCategory?['limit_amount'] as num?)?.toDouble();
  bool get _hasGrade => _vehicleCategory?['has_grade'] == true;
  String get _gradeName => _vehicleCategory?['grade_name']?.toString() ?? '';

  Future<void> _pickImage({required bool isStart}) async {
    try {
      final picked = await AppCameraCaptureDialog.capture(
        context,
        title: isStart ? 'Capture Day Start Meter' : 'Capture Day End Meter',
        helperTip: 'Align the vehicle odometer reading clearly within the frame',
      );
      if (picked == null) return;

      final persistentFile = await MediaStorageService.persistPickedFile(
        picked,
        category: MediaCategory.expenses,
        customPrefix: isStart ? 'odo_start' : 'odo_end',
      );
      final file = persistentFile ?? File(picked.path);
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);

      setState(() {
        if (isStart) {
          _startPhotoFile = file;
          _startPhotoBase64 = b64;
        } else {
          _endPhotoFile = file;
          _endPhotoBase64 = b64;
        }
      });
    } catch (e) {
      if (mounted) {
        showValidationErrorDialog(context, 'Failed to capture photo: $e');
      }
    }
  }

  void _onKmChanged() {
    final start = double.tryParse(_startKmController.text.trim()) ?? 0.0;
    final end = double.tryParse(_endKmController.text.trim()) ?? 0.0;
    if (end >= start && end > 0) {
      final km = end - start;
      _totalKmController.text = km.toStringAsFixed(2);
      final rate = _ratePerKm ?? 0.0;
      _amountController.text = (km * rate).toStringAsFixed(2);
    } else {
      _totalKmController.text = '0.00';
      _amountController.text = '0.00';
    }
  }

  Future<void> _submitTrip() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ExpenseProvider>();

    if (!_isEndingTrip) {
      // Starting trip: start image is strictly mandatory
      if (_startPhotoBase64 == null) {
        showValidationErrorDialog(
          context,
          'Day Start Odometer Photo is mandatory to start a trip.',
        );
        return;
      }

      final startKm = double.tryParse(_startKmController.text.trim()) ?? 0.0;
      final catId = _vehicleCategory?['id'];
      if (catId == null) {
        showValidationErrorDialog(
          context,
          'Personal Vehicle category not found or not configured.',
        );
        return;
      }

      final result = await provider.createDraftExpense(
        categoryId: catId,
        title: _titleController.text.trim(),
        amount: 0.0,
        odometerDayStart: startKm,
        odometerStartImage: _startPhotoBase64,
        description: _notesController.text.trim(),
      );

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Personal Vehicle Trip started successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      } else if (mounted && provider.requestError != null) {
        showValidationErrorDialog(context, provider.requestError!);
      }
    } else {
      // Ending trip: end image and end km are strictly mandatory
      final trip = _activeTrip!;
      final hasStartImage = trip['has_odometer_start_image'] == true || _startPhotoBase64 != null;
      if (!hasStartImage) {
        showValidationErrorDialog(
          context,
          'Day Start Odometer Photo is missing.',
        );
        return;
      }

      final hasEndImage = trip['has_odometer_end_image'] == true || _endPhotoBase64 != null;
      if (!hasEndImage) {
        showValidationErrorDialog(
          context,
          'Day End Odometer Photo is mandatory to complete the trip.',
        );
        return;
      }

      final startKm = double.tryParse(_startKmController.text.trim()) ?? 0.0;
      final endKm = double.tryParse(_endKmController.text.trim()) ?? 0.0;
      if (endKm < startKm) {
        showValidationErrorDialog(
          context,
          'Day End reading cannot be less than Day Start reading.',
        );
        return;
      }

      final totalKm = endKm - startKm;
      final amount = double.tryParse(_amountController.text.trim()) ?? (totalKm * (_ratePerKm ?? 0.0));

      final result = await provider.updateDraftExpense(
        expenseId: trip['id'],
        title: _titleController.text.trim(),
        amount: amount,
        odometerDayStart: startKm,
        odometerDayEnd: endKm,
        totalKmRun: totalKm,
        odometerStartImage: _startPhotoBase64,
        odometerEndImage: _endPhotoBase64,
        description: _notesController.text.trim(),
      );

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trip completed! Total: ${totalKm.toStringAsFixed(1)} KM (৳${amount.toStringAsFixed(2)})'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      } else if (mounted && provider.requestError != null) {
        showValidationErrorDialog(context, provider.requestError!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Personal Vehicle',
          style: TextStyle(
            color: AppColors.primaryStrong,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ProfileAvatar(currentDestinationLabel: 'Vehicle Trip'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: !_isInitialized
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 100),
                    child: CircularProgressIndicator(),
                  ),
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Active Trip Status Banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _isEndingTrip ? Colors.teal[50] : Colors.blue[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isEndingTrip ? Colors.teal[300]! : Colors.blue[200]!,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _isEndingTrip ? Colors.teal[100] : Colors.blue[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isEndingTrip ? Icons.timer_outlined : Icons.directions_bike_outlined,
                                color: _isEndingTrip ? Colors.teal[900] : Colors.blue[900],
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isEndingTrip ? 'Trip in Progress' : 'Ready to Start Trip',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: _isEndingTrip ? Colors.teal[900] : Colors.blue[900],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isEndingTrip
                                        ? 'Start KM: ${_startKmController.text} • Capture Day End meter to close trip.'
                                        : 'Capture Day Start meter image & reading to begin your daily journey.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _isEndingTrip ? Colors.teal[800] : Colors.blue[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Rate Card Info Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: (!_hasGrade || _ratePerKm == null)
                              ? Colors.amber.withOpacity(0.12)
                              : AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (!_hasGrade || _ratePerKm == null)
                                ? Colors.amber[700]!
                                : AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              (!_hasGrade || _ratePerKm == null) ? Icons.warning_amber_rounded : Icons.info_outline,
                              size: 20,
                              color: (!_hasGrade || _ratePerKm == null) ? Colors.amber[800] : AppColors.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                !_hasGrade
                                    ? 'No employee grade assigned.'
                                    : _ratePerKm == null
                                        ? 'Personal vehicle mileage is not configured for grade ${_gradeName.isNotEmpty ? _gradeName : "Unassigned"}.'
                                        : 'Mileage Rate: ৳${_ratePerKm!.toStringAsFixed(2)} per km (${_gradeName.isNotEmpty ? _gradeName : "Grade"})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: (!_hasGrade || _ratePerKm == null) ? Colors.amber[900] : AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Title Field
                      const Text('Trip Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Trip Title / Purpose *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Title is required.' : null,
                      ),
                      const SizedBox(height: 20),

                      // Day Start Section
                      const Text('Day Start (Trip Start)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _startKmController,
                              readOnly: _isEndingTrip,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Start KM Reading *',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                filled: _isEndingTrip,
                                fillColor: _isEndingTrip ? Colors.grey[100] : null,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Start KM required.';
                                final num = double.tryParse(val.trim());
                                if (num == null || num < 0) return 'Invalid KM.';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                side: BorderSide(
                                  color: (_startPhotoFile != null || _activeTrip?['has_odometer_start_image'] == true)
                                      ? Colors.green
                                      : AppColors.primary,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _isEndingTrip ? null : () => _pickImage(isStart: true),
                              icon: Icon(
                                (_startPhotoFile != null || _activeTrip?['has_odometer_start_image'] == true)
                                    ? Icons.check_circle
                                    : Icons.photo_camera,
                                size: 18,
                                color: (_startPhotoFile != null || _activeTrip?['has_odometer_start_image'] == true)
                                    ? Colors.green
                                    : AppColors.primary,
                              ),
                              label: Text(
                                (_startPhotoFile != null || _activeTrip?['has_odometer_start_image'] == true)
                                    ? 'Start Photo ✓'
                                    : 'Take Photo *',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: (_startPhotoFile != null || _activeTrip?['has_odometer_start_image'] == true)
                                      ? Colors.green
                                      : AppColors.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_startPhotoFile != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            '✓ Photo captured (${_startPhotoFile!.path.split('/').last})',
                            style: const TextStyle(fontSize: 11, color: Colors.green),
                          ),
                        ),

                      // Day End Section (Enabled only when ending trip)
                      if (_isEndingTrip) ...[
                        const SizedBox(height: 20),
                        const Text('Day End (Trip End)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _endKmController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'End KM Reading *',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                onChanged: (_) => _onKmChanged(),
                                validator: (val) {
                                  if (!_isEndingTrip) return null;
                                  if (val == null || val.trim().isEmpty) return 'End KM required.';
                                  final end = double.tryParse(val.trim());
                                  final start = double.tryParse(_startKmController.text.trim()) ?? 0.0;
                                  if (end == null || end < start) return 'Must be ≥ Start KM.';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                  side: BorderSide(
                                    color: (_endPhotoFile != null || _activeTrip?['has_odometer_end_image'] == true)
                                        ? Colors.green
                                        : AppColors.primary,
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _pickImage(isStart: false),
                                icon: Icon(
                                  (_endPhotoFile != null || _activeTrip?['has_odometer_end_image'] == true)
                                      ? Icons.check_circle
                                      : Icons.photo_camera,
                                  size: 18,
                                  color: (_endPhotoFile != null || _activeTrip?['has_odometer_end_image'] == true)
                                      ? Colors.green
                                      : AppColors.primary,
                                ),
                                label: Text(
                                  (_endPhotoFile != null || _activeTrip?['has_odometer_end_image'] == true)
                                      ? 'End Photo ✓'
                                      : 'Take Photo *',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: (_endPhotoFile != null || _activeTrip?['has_odometer_end_image'] == true)
                                        ? Colors.green
                                        : AppColors.primary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_endPhotoFile != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              '✓ Photo captured (${_endPhotoFile!.path.split('/').last})',
                              style: const TextStyle(fontSize: 11, color: Colors.green),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Calculated Summary Box
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderSoft),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Text('Total KM Run', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_totalKmController.text.isNotEmpty ? _totalKmController.text : "0.00"} KM',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ],
                              ),
                              Container(height: 32, width: 1, color: AppColors.borderSoft),
                              Column(
                                children: [
                                  const Text('Total Amount', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '৳${_amountController.text.isNotEmpty ? _amountController.text : "0.00"}',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      // Notes
                      const Text('Notes / Remarks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesController,
                        decoration: InputDecoration(
                          hintText: 'Enter optional route or purpose remarks...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 32),

                      // Submit Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isEndingTrip ? Colors.green : AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: provider.isSubmitting ? null : _submitTrip,
                        child: provider.isSubmitting
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                _isEndingTrip ? 'Complete Trip' : 'Start Trip',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
