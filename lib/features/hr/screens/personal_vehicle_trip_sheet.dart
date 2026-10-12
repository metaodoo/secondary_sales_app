import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/widgets/app_camera_capture_dialog.dart';
import 'package:secondary_sales/core/services/media_storage_service.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/features/hr/expense_provider.dart';

class PersonalVehicleTripSheet extends StatefulWidget {
  final Map<String, dynamic>? activeTrip;

  const PersonalVehicleTripSheet({super.key, this.activeTrip});

  static Future<bool?> show(
    BuildContext context, {
    Map<String, dynamic>? activeTrip,
    required ExpenseProvider provider,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChangeNotifierProvider.value(
        value: provider,
        child: PersonalVehicleTripSheet(activeTrip: activeTrip),
      ),
    );
  }

  @override
  State<PersonalVehicleTripSheet> createState() => _PersonalVehicleTripSheetState();
}

class _PersonalVehicleTripSheetState extends State<PersonalVehicleTripSheet> {
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
  bool _isEndingTrip = false;

  @override
  void initState() {
    super.initState();
    _isEndingTrip = widget.activeTrip != null;

    final provider = context.read<ExpenseProvider>();
    _vehicleCategory = provider.categories.cast<Map<String, dynamic>?>().firstWhere(
      (c) => c?['expense_allowance_type'] == 'personal_vehicle_mileage_rate_card',
      orElse: () => null,
    );

    if (_isEndingTrip) {
      final trip = widget.activeTrip!;
      _titleController.text = trip['title'] ?? 'Personal Vehicle Travel';
      final start = (trip['odometer_day_start'] as num?)?.toDouble() ?? 0.0;
      _startKmController.text = start > 0 ? start.toStringAsFixed(1) : '';
      _notesController.text = trip['description'] ?? '';
    } else {
      _titleController.text = 'Personal Vehicle Travel';
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick photo: $e'), backgroundColor: Colors.red),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Day Start Odometer Photo is mandatory to start a trip.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final startKm = double.tryParse(_startKmController.text.trim()) ?? 0.0;
      final catId = _vehicleCategory?['id'] ?? widget.activeTrip?['category_id'];
      if (catId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Personal Vehicle category not found or not configured.'),
            backgroundColor: Colors.red,
          ),
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
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Personal Vehicle Trip started successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted && provider.requestError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.requestError!), backgroundColor: Colors.red),
        );
      }
    } else {
      // Ending trip: end image and end km are strictly mandatory
      final trip = widget.activeTrip!;
      final hasStartImage = trip['has_odometer_start_image'] == true || _startPhotoBase64 != null;
      if (!hasStartImage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Day Start Odometer Photo is missing.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final hasEndImage = trip['has_odometer_end_image'] == true || _endPhotoBase64 != null;
      if (!hasEndImage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Day End Odometer Photo is mandatory to complete the trip.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final startKm = double.tryParse(_startKmController.text.trim()) ?? 0.0;
      final endKm = double.tryParse(_endKmController.text.trim()) ?? 0.0;
      if (endKm < startKm) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Day End reading cannot be less than Day Start reading.'),
            backgroundColor: Colors.red,
          ),
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
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trip completed! Total: ${totalKm.toStringAsFixed(1)} KM (৳${amount.toStringAsFixed(2)})'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted && provider.requestError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.requestError!), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.two_wheeler, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEndingTrip ? 'End Vehicle Trip' : 'Start Vehicle Trip',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isEndingTrip
                                  ? 'Record meter reading & end photo'
                                  : 'Capture start meter & begin trip',
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Rate Card Info Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (!_hasGrade || _ratePerKm == null)
                        ? Colors.amber.withOpacity(0.12)
                        : AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
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
                        size: 18,
                        color: (!_hasGrade || _ratePerKm == null) ? Colors.amber[800] : AppColors.primary,
                      ),
                      const SizedBox(width: 8),
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
                const SizedBox(height: 16),

                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Trip Title / Purpose *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Title is required.' : null,
                ),
                const SizedBox(height: 16),

                // Day Start Section
                const Text('Day Start (Trip Start)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          side: BorderSide(
                            color: (_startPhotoFile != null || widget.activeTrip?['has_odometer_start_image'] == true)
                                ? Colors.green
                                : AppColors.primary,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isEndingTrip ? null : () => _pickImage(isStart: true),
                        icon: Icon(
                          (_startPhotoFile != null || widget.activeTrip?['has_odometer_start_image'] == true)
                              ? Icons.check_circle
                              : Icons.photo_camera,
                          size: 18,
                          color: (_startPhotoFile != null || widget.activeTrip?['has_odometer_start_image'] == true)
                              ? Colors.green
                              : AppColors.primary,
                        ),
                        label: Text(
                          (_startPhotoFile != null || widget.activeTrip?['has_odometer_start_image'] == true)
                              ? 'Start Photo'
                              : 'Take Photo *',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: (_startPhotoFile != null || widget.activeTrip?['has_odometer_start_image'] == true)
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
                  const Text('Day End (Trip End)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            side: BorderSide(
                              color: (_endPhotoFile != null || widget.activeTrip?['has_odometer_end_image'] == true)
                                  ? Colors.green
                                  : AppColors.primary,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _pickImage(isStart: false),
                          icon: Icon(
                            (_endPhotoFile != null || widget.activeTrip?['has_odometer_end_image'] == true)
                                ? Icons.check_circle
                                : Icons.photo_camera,
                            size: 18,
                            color: (_endPhotoFile != null || widget.activeTrip?['has_odometer_end_image'] == true)
                                ? Colors.green
                                : AppColors.primary,
                          ),
                          label: Text(
                            (_endPhotoFile != null || widget.activeTrip?['has_odometer_end_image'] == true)
                                ? 'End Photo'
                                : 'Take Photo *',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: (_endPhotoFile != null || widget.activeTrip?['has_odometer_end_image'] == true)
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

                  // Calculated Summary
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('Total KM Run', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            const SizedBox(height: 2),
                            Text(
                              '${_totalKmController.text.isNotEmpty ? _totalKmController.text : "0.00"} KM',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                        Container(height: 24, width: 1, color: AppColors.borderSoft),
                        Column(
                          children: [
                            const Text('Total Amount', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            const SizedBox(height: 2),
                            Text(
                              '৳${_amountController.text.isNotEmpty ? _amountController.text : "0.00"}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'Notes / Route Remarks (Optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: provider.isSubmitting ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isEndingTrip ? Colors.green : AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: provider.isSubmitting ? null : _submitTrip,
                        child: provider.isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(_isEndingTrip ? 'Complete Trip' : 'Start Trip'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
