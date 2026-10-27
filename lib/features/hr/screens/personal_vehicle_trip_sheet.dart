import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/widgets/app_camera_capture_dialog.dart';
import 'package:secondary_sales/core/services/media_storage_service.dart';
import 'package:secondary_sales/core/widgets/ss_keyboard_inset.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/util/dialog_helper.dart';
import 'package:secondary_sales/features/hr/expense_provider.dart';

class PersonalVehicleTripSheet extends StatefulWidget {
  final Map<String, dynamic>? activeTrip;
  final DateTime? initialDate;

  const PersonalVehicleTripSheet({super.key, this.activeTrip, this.initialDate});

  static Future<bool?> show(
    BuildContext context, {
    Map<String, dynamic>? activeTrip,
    DateTime? initialDate,
    required ExpenseProvider provider,
  }) {
    // Built once: the sheet route calls builder again on every frame of the
    // keyboard animation, and a new widget there would rebuild the whole form.
    final sheet = ChangeNotifierProvider.value(
      value: provider,
      child: PersonalVehicleTripSheet(activeTrip: activeTrip, initialDate: initialDate),
    );
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
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

  DateTime _selectedDate = DateTime.now();
  File? _startPhotoFile;
  String? _startPhotoBase64;
  File? _endPhotoFile;
  String? _endPhotoBase64;

  Map<String, dynamic>? _vehicleCategory;
  bool _isEndingTrip = false;
  bool _forceBothReadings = false;

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
      if (trip['date'] != null && trip['date'].toString().isNotEmpty) {
        _selectedDate = DateTime.tryParse(trip['date']) ?? DateTime.now();
      }
      final start = (trip['odometer_day_start'] as num?)?.toDouble() ?? 0.0;
      _startKmController.text = start > 0 ? start.toStringAsFixed(1) : '';
      _notesController.text = trip['description'] ?? '';
    } else {
      _titleController.text = 'Personal Vehicle Travel';
      _selectedDate = widget.initialDate ?? DateTime.now();
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

  bool get _isBackDate => !_isEndingTrip && !DateUtils.isSameDay(_selectedDate, DateTime.now());
  bool get _requiresEndReading => _isEndingTrip || _isBackDate || _forceBothReadings;
  double? get _ratePerKm => (_vehicleCategory?['limit_amount'] as num?)?.toDouble();
  bool get _hasGrade => _vehicleCategory?['has_grade'] == true;
  String get _gradeName => _vehicleCategory?['grade_name']?.toString() ?? '';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 90)),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

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
        showValidationErrorDialog(context, 'Failed to pick photo: $e');
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
    final catId = _vehicleCategory?['id'] ?? widget.activeTrip?['category_id'];
    if (catId == null) {
      showValidationErrorDialog(
        context,
        'Personal Vehicle category not found or not configured in your grade.',
      );
      return;
    }

    final dateStr = _selectedDate.toString().split(' ')[0];

    // Case 1: Back-date or full trip entry (requires both start & end meter readings & photos)
    if (_isBackDate || _forceBothReadings) {
      if (_startPhotoBase64 == null) {
        showValidationErrorDialog(context, 'Day Start Odometer Photo is mandatory.');
        return;
      }
      if (_endPhotoBase64 == null) {
        showValidationErrorDialog(context, 'Day End Odometer Photo is mandatory.');
        return;
      }

      final startKm = double.tryParse(_startKmController.text.trim()) ?? 0.0;
      final endKm = double.tryParse(_endKmController.text.trim()) ?? 0.0;
      if (endKm < startKm) {
        showValidationErrorDialog(context, 'Day End reading cannot be less than Day Start reading.');
        return;
      }

      final totalKm = endKm - startKm;
      final amount = double.tryParse(_amountController.text.trim()) ?? (totalKm * (_ratePerKm ?? 0.0));

      final result = await provider.createDraftExpense(
        categoryId: catId,
        title: _titleController.text.trim(),
        amount: amount,
        date: dateStr,
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
            content: Text('Trip recorded for $dateStr! (${totalKm.toStringAsFixed(1)} KM)'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted && provider.requestError != null) {
        showValidationErrorDialog(context, provider.requestError!);
      }
      return;
    }

    // Case 2: Starting a fresh trip
    if (!_isEndingTrip) {
      if (_startPhotoBase64 == null) {
        showValidationErrorDialog(context, 'Day Start Odometer Photo is mandatory to start a trip.');
        return;
      }

      final startKm = double.tryParse(_startKmController.text.trim()) ?? 0.0;
      final result = await provider.createDraftExpense(
        categoryId: catId,
        title: _titleController.text.trim(),
        amount: 0.0,
        date: dateStr,
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
        showValidationErrorDialog(context, provider.requestError!);
      }
    } else {
      // Case 3: Ending trip
      final trip = widget.activeTrip!;
      final hasStartImage = trip['has_odometer_start_image'] == true || _startPhotoBase64 != null;
      if (!hasStartImage) {
        showValidationErrorDialog(context, 'Day Start Odometer Photo is missing.');
        return;
      }

      final hasEndImage = trip['has_odometer_end_image'] == true || _endPhotoBase64 != null;
      if (!hasEndImage) {
        showValidationErrorDialog(context, 'Day End Odometer Photo is mandatory to complete the trip.');
        return;
      }

      final startKm = double.tryParse(_startKmController.text.trim()) ?? 0.0;
      final endKm = double.tryParse(_endKmController.text.trim()) ?? 0.0;
      if (endKm < startKm) {
        showValidationErrorDialog(context, 'Day End reading cannot be less than Day Start reading.');
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
        showValidationErrorDialog(context, provider.requestError!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    return SsKeyboardInset(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEndingTrip
                              ? 'Complete Vehicle Trip'
                              : _isBackDate
                                  ? 'Record Back-Date Trip'
                                  : 'Start Vehicle Trip',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isEndingTrip
                              ? 'Enter Day End odometer reading to finish'
                              : _isBackDate
                                  ? 'Enter start & end readings for ${_selectedDate.toString().split(' ')[0]}'
                                  : 'Capture Day Start odometer to start daily travel',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                if (_isEndingTrip) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.history, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Completing active trip. Need a back-dated trip instead?',
                            style: TextStyle(fontSize: 11, color: Colors.blue),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () {
                            setState(() {
                              _isEndingTrip = false;
                              _selectedDate = DateTime.now().subtract(const Duration(days: 1));
                              _startKmController.clear();
                              _endKmController.clear();
                              _totalKmController.clear();
                              _amountController.clear();
                              _startPhotoFile = null;
                              _startPhotoBase64 = null;
                              _endPhotoFile = null;
                              _endPhotoBase64 = null;
                            });
                          },
                          child: const Text('Switch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Rate Card Info
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

                // Date Picker + Trip Title Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Trip Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    InkWell(
                      onTap: _isEndingTrip || provider.isSubmitting ? null : _pickDate,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _isEndingTrip ? Colors.grey[200] : AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isEndingTrip ? Colors.grey[350]! : AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 13,
                              color: _isEndingTrip ? Colors.grey[600] : AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _selectedDate.toString().split(' ')[0],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _isEndingTrip ? Colors.grey[600] : AppColors.primary,
                              ),
                            ),
                            if (!_isEndingTrip) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.primary),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (!_isEndingTrip && DateUtils.isSameDay(_selectedDate, DateTime.now()))
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 2),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _forceBothReadings = !_forceBothReadings;
                        });
                      },
                      child: Row(
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: Checkbox(
                              value: _forceBothReadings,
                              onChanged: (val) {
                                setState(() {
                                  _forceBothReadings = val ?? false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Wraps on narrow screens and large text.
                          const Expanded(
                            child: Text(
                              'Trip already completed today? Record start & end now',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),

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
                        onChanged: (_) => _onKmChanged(),
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
                              ? 'Start Photo ✓'
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
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '✓ Photo captured (${_startPhotoFile!.path.split('/').last})',
                      style: const TextStyle(fontSize: 11, color: Colors.green),
                    ),
                  ),

                // Day End Section (Enabled if ending trip, back-dating, or entering completed trip)
                if (_requiresEndReading) ...[
                  const SizedBox(height: 16),
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
                            if (!_requiresEndReading) return null;
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
                                ? 'End Photo ✓'
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
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '✓ Photo captured (${_endPhotoFile!.path.split('/').last})',
                        style: const TextStyle(fontSize: 11, color: Colors.green),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Calculated Summary Box
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
                          backgroundColor: _requiresEndReading ? Colors.green : AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: provider.isSubmitting ? null : _submitTrip,
                        child: provider.isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                _isEndingTrip
                                    ? 'Complete Trip'
                                    : _isBackDate
                                        ? 'Record Back-Date Trip'
                                        : _forceBothReadings
                                            ? 'Record Completed Trip'
                                            : 'Start Trip',
                              ),
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
