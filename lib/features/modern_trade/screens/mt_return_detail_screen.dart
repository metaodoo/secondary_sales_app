import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/constants.dart';
import 'package:secondary_sales/core/services/media_storage_service.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/core/widgets/app_camera_capture_dialog.dart';
import 'package:secondary_sales/data/models/modern_trade/mt_return_request.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/modern_trade/mt_return_provider.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_return_line_edit_sheet.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_return_line_history_sheet.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_return_product_selection_sheet.dart';
import 'package:secondary_sales/features/modern_trade/screens/mt_return_type_sheet.dart';
import 'package:secondary_sales/features/sales/screens/validate_delivery_screen.dart';

class MtReturnDetailScreen extends StatefulWidget {
  final int returnId;

  const MtReturnDetailScreen({
    super.key,
    required this.returnId,
  });

  @override
  State<MtReturnDetailScreen> createState() => _MtReturnDetailScreenState();
}

class _MtReturnDetailScreenState extends State<MtReturnDetailScreen> {
  File? _dmChallanImageFile;
  String? _dmChallanImageBase64;
  String? _dmChallanImageName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MtReturnProvider>().fetchReturnDetail(widget.returnId);
    });
  }

  Future<bool> _pickChallanImage(ImageSource source) async {
    try {
      final XFile? picked;
      if (source == ImageSource.camera) {
        picked = await AppCameraCaptureDialog.capture(
          context,
          title: 'Capture Return Challan',
          helperTip: 'Align the return challan document inside the frame',
        );
      } else {
        final picker = ImagePicker();
        picked = await picker.pickImage(
          source: source,
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 70,
        );
      }
      if (picked == null) return false;
      final photo = picked;
      final file = await MediaStorageService.persistPickedFile(photo, category: MediaCategory.damages);
      if (file == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image file is invalid or empty. Please retake.')),
          );
        }
        return false;
      }
      final bytes = await file.readAsBytes();
      final base64Str = base64Encode(bytes);
      setState(() {
        _dmChallanImageFile = file;
        _dmChallanImageBase64 = base64Str;
        _dmChallanImageName = photo.name.isNotEmpty
            ? photo.name
            : 'return_challan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      });
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick photo: $e')),
        );
      }
      return false;
    }
  }

  Future<bool> _promptDmCaptureImage(BuildContext context) async {
    return await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text(
                    'Challan Photo Evidence',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '*',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Upload a photo of the return challan document (mandatory for DM before submitting to KAS).',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(ctx).pop(true);
                        await _pickChallanImage(ImageSource.camera);
                      },
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Camera'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryStrong,
                        side: const BorderSide(color: AppColors.primaryStrong),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(ctx).pop(true);
                        await _pickChallanImage(ImageSource.gallery);
                      },
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Gallery'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryStrong,
                        side: const BorderSide(color: AppColors.primaryStrong),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
              ),
            ],
          ),
        ),
      ),
    ) ?? false;
  }

  void _onExecuteAction(String action, String actionLabel) async {
    final provider = context.read<MtReturnProvider>();
    final rr = provider.selectedReturn;
    final isSubmittingToKas = action.toLowerCase().contains('submit_kas') ||
        (rr != null && rr.state.toLowerCase() == 'dm');

    final hasExistingAttachment = (rr != null && rr.attachments.isNotEmpty) || _dmChallanImageBase64 != null;

    if (isSubmittingToKas && !hasExistingAttachment) {
      await _promptDmCaptureImage(context);
      if (_dmChallanImageBase64 == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot submit to KAS: Return Challan photo evidence is mandatory for DM.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;

    final isConfirmAction = actionLabel.toLowerCase().startsWith('confirm');
    final dialogTitle = isConfirmAction ? 'Confirm Return Request' : 'Confirm $actionLabel';
    final dialogContent = isConfirmAction
        ? 'Are you sure you want to confirm this return request?'
        : 'Are you sure you want to $actionLabel this return request?';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(dialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dialogContent),
            if (_dmChallanImageFile != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Photo attached: ${_dmChallanImageName ?? "Return Challan"}',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryStrong),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await provider.executeAction(
        widget.returnId,
        action,
        attachmentBase64: _dmChallanImageBase64,
        attachmentFilename: _dmChallanImageName,
      );
      if (success && mounted) {
        setState(() {
          _dmChallanImageFile = null;
          _dmChallanImageBase64 = null;
          _dmChallanImageName = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$actionLabel completed successfully!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } else if (provider.errorMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage!),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _onEditOrSplitLine(MtReturnRequestLine line, MtReturnRequest rr) async {
    final updatedLineDataList = await MtReturnLineEditSheet.show(
      context,
      line: line,
      returnBucket: rr.returnBucket,
      state: rr.state,
    );

    if (updatedLineDataList != null && updatedLineDataList.isNotEmpty && mounted) {
      final existingLinesPayload = <Map<String, dynamic>>[];

      // Keep other product lines as is
      for (final l in rr.lines) {
        if (l.id != line.id) {
          existingLinesPayload.add({
            'id': l.id,
            'product_id': l.productId,
            'lot_id': l.lotId,
            'saleable_qty': l.saleableQty,
            'non_saleable_qty': l.nonSaleableQty,
            'quality_qty': l.qualityQty,
          });
        }
      }

      // Add updated and newly split line(s)
      existingLinesPayload.addAll(updatedLineDataList);

      final provider = context.read<MtReturnProvider>();
      final ok = await provider.updateReturnLines(widget.returnId, existingLinesPayload);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lines updated and lots split successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (provider.errorMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage!),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _onAddNewProductLine(MtReturnRequest rr) async {
    final result = await MtReturnProductSelectionSheet.show(
      context,
      returnBucket: rr.returnBucket,
      state: rr.state,
      outletId: rr.partnerId,
    );
    if (result != null && mounted) {
      final existingLinesPayload = rr.lines.map((l) => {
        'id': l.id,
        'product_id': l.productId,
        'lot_id': l.lotId,
        'saleable_qty': l.saleableQty,
        'non_saleable_qty': l.nonSaleableQty,
        'quality_qty': l.qualityQty,
      }).toList();

      existingLinesPayload.add({
        'product_id': result['product_id'],
        'lot_id': result['lot_id'],
        'saleable_qty': result['saleable_qty'],
        'non_saleable_qty': result['non_saleable_qty'],
        'quality_qty': result['quality_qty'],
      });

      final provider = context.read<MtReturnProvider>();
      final ok = await provider.updateReturnLines(widget.returnId, existingLinesPayload);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product line added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (provider.errorMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage!),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _onDeleteLine(MtReturnRequestLine line, MtReturnRequest rr) async {
    if (rr.lines.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A Return Request must have at least one product line.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Product Line?'),
        content: Text('Are you sure you want to remove "${line.productName}" from this return request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final payload = <Map<String, dynamic>>[
        {'id': line.id, 'delete': true},
      ];
      final provider = context.read<MtReturnProvider>();
      final ok = await provider.updateReturnLines(widget.returnId, payload);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product line removed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (provider.errorMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage!),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _openFilePreviewDialog(File file, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.file(
                  file,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openImagePreviewDialog(BuildContext context, String imageUrl, String title) {
    final fullUrl = imageUrl.startsWith('http')
        ? imageUrl
        : '${AppConstants.baseUrl}$imageUrl';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.network(
                  fullUrl,
                  headers: context.read<AuthProvider>().authHeaders,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (context, err, st) => const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, size: 54, color: Colors.white70),
                      SizedBox(height: 10),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openReturnTypePicker(MtReturnRequest rr) async {
    if (rr.state.toLowerCase() != 'kao') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Return type can only be changed in KAO state.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedType = await showMtReturnTypePicker(
      context,
      returnBucket: rr.returnBucket,
      currentType: rr.returnType,
    );

    if (selectedType == null || selectedType == rr.returnType || !mounted) return;

    final isToReplacement = selectedType == 'replacement';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isToReplacement ? 'Switch to Replacement?' : 'Switch to Return?'),
        content: Text(
          isToReplacement
              ? 'This will change the Return Type to Replacement and generate an outgoing replacement delivery transfer for this request upon KAS submission.'
              : 'This will change the Return Type to Return (Scrap Only). No outgoing delivery transfer will be generated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isToReplacement ? const Color(0xFF0288D1) : const Color(0xFFE65100),
            ),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<MtReturnProvider>();
    final success = await provider.changeReturnType(rr.id, selectedType);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully switched to ${isToReplacement ? "Replacement" : "Return"}!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } else if (provider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage!),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MtReturnProvider>();
    final auth = context.watch<AuthProvider>();
    final rr = provider.selectedReturn;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(rr != null ? rr.name : 'Return Request Detail'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.fetchReturnDetail(widget.returnId),
          ),
        ],
      ),
      body: provider.isLoading && rr == null
          ? const Center(child: CircularProgressIndicator())
          : rr == null
              ? Center(
                  child: Text(
                    provider.errorMessage ?? 'Return request not found.',
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => provider.fetchReturnDetail(widget.returnId),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Status & Outlet Card
                        _buildHeaderCard(rr),
                        const SizedBox(height: 16),

                        // Return Challan Photo Evidence Preview Card (available in ALL states)
                        _buildAttachmentsPreviewCard(rr),
                        const SizedBox(height: 16),

                        // Prominent Return Type Switcher Banner (Non-Saleable & Quality only)
                        if (!rr.isSaleable) ...[
                          _buildReturnTypeBanner(rr),
                          const SizedBox(height: 16),
                        ],

                        // Linked Transfers Section
                        _buildTransfersSection(rr),
                        const SizedBox(height: 16),

                        // Lines Section
                        _buildLinesSection(rr, auth),
                        const SizedBox(height: 80), // bottom space for sticky buttons
                      ],
                    ),
                  ),
                ),
      bottomNavigationBar: rr != null ? _buildBottomActionBar(rr, auth, provider) : null,
    );
  }

  Widget _buildHeaderCard(MtReturnRequest rr) {
    final isSaleable = rr.isSaleable;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                rr.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              _buildStatusBadge(rr.state, rr.stateDisplay),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSaleable ? Colors.teal.shade50 : Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isSaleable ? Colors.teal.shade300 : Colors.purple.shade300),
                ),
                child: Text(
                  rr.returnBucketDisplay,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSaleable ? Colors.teal.shade800 : Colors.purple.shade800,
                  ),
                ),
              ),
              if (!isSaleable) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: rr.isDirectReturn ? Colors.deepOrange.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: rr.isDirectReturn ? Colors.deepOrange.shade300 : Colors.blue.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        rr.isDirectReturn
                            ? Icons.assignment_return_outlined
                            : Icons.published_with_changes_outlined,
                        size: 13,
                        color: rr.isDirectReturn ? Colors.deepOrange.shade800 : Colors.blue.shade800,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rr.returnTypeDisplay,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: rr.isDirectReturn ? Colors.deepOrange.shade800 : Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: 8),
              if (rr.date != null)
                Text(
                  'Date: ${rr.date}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
            ],
          ),
          const Divider(height: 20),
          // Outlet Info
          Text(
            rr.partnerName ?? 'Outlet',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          if (rr.ssCode != null && rr.ssCode!.isNotEmpty)
            Text('SS Code: ${rr.ssCode}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          if (rr.zoneName != null)
            Text('Zone: ${rr.zoneName}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          if (rr.warehouseName != null)
            Text('Warehouse: ${rr.warehouseName}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          if (rr.returnScrapLocationName != null)
            Text('Scrap Loc: ${rr.returnScrapLocationName}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          if (rr.totalAmount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Return Amount',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                Text(
                  '৳${rr.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primaryStrong),
                ),
              ],
            ),
          ],
          if (rr.notes != null && rr.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.notes, size: 16, color: AppColors.primaryStrong),
                      SizedBox(width: 6),
                      Text(
                        'Remarks / Notes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    rr.notes!.trim(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttachmentsPreviewCard(MtReturnRequest rr) {
    final imageAtt = rr.primaryImageAttachment;
    final firstAtt = imageAtt ?? (rr.attachments.isNotEmpty ? rr.attachments.first : null);
    final hasServerImage = firstAtt != null;
    final hasLocalImage = _dmChallanImageFile != null;
    final hasAnyImage = hasServerImage || hasLocalImage;
    final isDmState = rr.state.toLowerCase() == 'dm';

    final String serverFullUrl;
    if (firstAtt != null) {
      final rawUrl = firstAtt.imageUrl.isNotEmpty ? firstAtt.imageUrl : firstAtt.url;
      serverFullUrl = rawUrl.startsWith('http') ? rawUrl : '${AppConstants.baseUrl}$rawUrl';
    } else {
      serverFullUrl = '';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Challan Photo Evidence',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  if (!hasAnyImage && isDmState) ...[
                    const SizedBox(width: 4),
                    const Text(
                      '*',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ],
              ),
              if (hasServerImage && firstAtt.isImage)
                TextButton.icon(
                  onPressed: () => _openImagePreviewDialog(context, serverFullUrl, firstAtt.name),
                  icon: const Icon(Icons.fullscreen, size: 18, color: AppColors.primaryStrong),
                  label: const Text(
                    'Preview',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryStrong),
                  ),
                )
              else if (hasLocalImage)
                TextButton.icon(
                  onPressed: () => _openFilePreviewDialog(
                    _dmChallanImageFile!,
                    _dmChallanImageName ?? 'Return Challan Photo',
                  ),
                  icon: const Icon(Icons.fullscreen, size: 18, color: AppColors.primaryStrong),
                  label: const Text(
                    'Preview',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryStrong),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            hasAnyImage
                ? 'Upload a photo of the return challan document.'
                : (isDmState
                    ? 'Return Challan photo is mandatory before submitting to KAS.'
                    : 'Upload a clear photo of the return challan document.'),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          if (hasLocalImage)
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _openFilePreviewDialog(
                    _dmChallanImageFile!,
                    _dmChallanImageName ?? 'Return Challan Photo',
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          _dmChallanImageFile!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _openFilePreviewDialog(
                      _dmChallanImageFile!,
                      _dmChallanImageName ?? 'Return Challan Photo',
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _dmChallanImageName ?? 'Photo Attached',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Tap to preview photo evidence',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.visibility_outlined,
                    color: AppColors.primaryStrong,
                  ),
                  tooltip: 'Preview Photo',
                  onPressed: () => _openFilePreviewDialog(
                    _dmChallanImageFile!,
                    _dmChallanImageName ?? 'Return Challan Photo',
                  ),
                ),
                if (isDmState)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    tooltip: 'Remove Photo',
                    onPressed: () {
                      setState(() {
                        _dmChallanImageFile = null;
                        _dmChallanImageBase64 = null;
                        _dmChallanImageName = null;
                      });
                    },
                  ),
              ],
            )
          else if (hasServerImage)
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: firstAtt.isImage
                      ? () => _openImagePreviewDialog(context, serverFullUrl, firstAtt.name)
                      : null,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: firstAtt.isImage
                            ? Image.network(
                                serverFullUrl,
                                headers: context.read<AuthProvider>().authHeaders,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image, color: Colors.grey, size: 20),
                                ),
                              )
                            : Container(
                                width: 50,
                                height: 50,
                                color: Colors.blue.shade50,
                                child: const Icon(Icons.description_outlined, color: Colors.blue, size: 24),
                              ),
                      ),
                      if (firstAtt.isImage)
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: firstAtt.isImage
                        ? () => _openImagePreviewDialog(context, serverFullUrl, firstAtt.name)
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          firstAtt.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          firstAtt.isImage ? 'Tap to preview photo evidence' : 'Document Attachment',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (firstAtt.isImage)
                  IconButton(
                    icon: const Icon(
                      Icons.visibility_outlined,
                      color: AppColors.primaryStrong,
                    ),
                    tooltip: 'Preview Photo',
                    onPressed: () => _openImagePreviewDialog(context, serverFullUrl, firstAtt.name),
                  ),
              ],
            )
          else if (isDmState)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickChallanImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Camera'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryStrong,
                      side: const BorderSide(color: AppColors.primaryStrong),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickChallanImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryStrong,
                      side: const BorderSide(color: AppColors.primaryStrong),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade400, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'No photo evidence attached',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReturnTypeBanner(MtReturnRequest rr) {
    final canChangeType = (rr.canConvertToReplacement || rr.canConvertToReturn) && rr.state.toLowerCase() == 'kao';
    final isReplacement = rr.isReplacement;
    final primaryColor = isReplacement ? const Color(0xFF0288D1) : const Color(0xFFE65100);
    final bgColor = isReplacement ? const Color(0xFFE1F5FE) : const Color(0xFFFFF3E0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
            ),
            child: Icon(
              isReplacement ? Icons.published_with_changes_outlined : Icons.assignment_return_outlined,
              color: primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Return Type: ${rr.returnTypeDisplay}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isReplacement ? 'Replacement Delivery' : 'Scrap Only',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isReplacement
                    ? 'Outlet will receive fresh replacement goods.'
                    : 'Scrap intake only. No outgoing goods will be sent.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          if (canChangeType) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _openReturnTypePicker(rr),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: const Text('Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransfersSection(MtReturnRequest rr) {
    final transfers = rr.transfers
        .where((t) =>
            t.isDelivery || t.pickingTypeCode.toLowerCase() == 'outgoing')
        .toList();

    if (transfers.isEmpty) {
      if (!rr.isSaleable && rr.isDirectReturn) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFCC80)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFE65100), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Direct Return (Scrap Intake Only)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE65100),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Items are received into scrap location. No physical replacement delivery order is generated.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.brown.shade800,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, color: AppColors.primaryStrong, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Delivery (${transfers.length})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transfers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final t = transfers[index];
              return Material(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    final provider = context.read<MtReturnProvider>();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ValidateDeliveryScreen(
                          orderId: 0,
                          orderName: rr.name,
                          pickingId: t.id,
                          pickingName: t.name,
                          pickingState: t.state,
                          isReceipt: false,
                          saleType: 'primary',
                          businessType: 'mt',
                        ),
                      ),
                    );
                    if (mounted) {
                      provider.fetchReturnDetail(widget.returnId);
                    }
                  },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        t.name,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.open_in_new, size: 14, color: AppColors.primaryStrong),
                                  ],
                                ),
                              ),
                              _buildTransferStateBadge(t.state, t.stateDisplay),
                            ],
                          ),
                          if (t.origin != null) ...[
                            const SizedBox(height: 2),
                            Text('Origin: ${t.origin}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          ],
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _buildChip(t.pickingTypeName, Colors.blue),
                              if (t.isParent)
                                _buildChip('Parent Transfer', Colors.teal)
                              else if (t.parentTransferName != null)
                                _buildChip('Child of ${t.parentTransferName}', Colors.indigo),
                            ],
                          ),
                          if (t.moves.isNotEmpty) ...[
                            const Divider(height: 16),
                            ...t.moves.map((m) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '• ${m.productName}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        'Demand: ${m.demandQty.toStringAsFixed(0)} ${m.uomName}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLinesSection(MtReturnRequest rr, AuthProvider auth) {
    final isSaleable = rr.isSaleable;
    final lines = rr.lines;
    final canPerformCurrentStage = _canUserPerformStage(rr, auth);
    final canEditLines = !rr.isConfirmed &&
        auth.canDo(AppAction.mtReturnsSave) &&
        canPerformCurrentStage;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Returned Products (${lines.length})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              Row(
                children: [
                  if (canEditLines)
                    TextButton.icon(
                      onPressed: () => _onAddNewProductLine(rr),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.add_circle_outline, size: 16, color: AppColors.primaryStrong),
                      label: const Text(
                        'Add Product',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryStrong),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Text(
                    'Total Qty: ${rr.totalQty.toStringAsFixed(rr.totalQty.truncateToDouble() == rr.totalQty ? 0 : 2)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryStrong),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: lines.length,
            separatorBuilder: (context, index) => const Divider(height: 20),
            itemBuilder: (context, index) {
              final line = lines[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line.productName,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              line.defaultCode != null && line.defaultCode!.isNotEmpty
                                  ? 'Code: ${line.defaultCode} • UoM: ${line.uomName}'
                                  : 'UoM: ${line.uomName}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            if (line.lotName != null && line.lotName!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  'Lot: ${line.lotName}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (canEditLines) ...[
                        IconButton(
                          onPressed: () => _onEditOrSplitLine(line, rr),
                          icon: const Icon(Icons.edit_note_rounded, color: AppColors.primaryStrong, size: 22),
                          tooltip: 'Edit & Split Lots',
                        ),
                        IconButton(
                          onPressed: () => _onDeleteLine(line, rr),
                          icon: Icon(Icons.delete_outline, color: Colors.red.shade600, size: 20),
                          tooltip: 'Remove Product Line',
                        ),
                      ],
                      // Hamburger details button
                      IconButton(
                        onPressed: () => MtReturnLineHistorySheet.show(
                          context,
                          line: line,
                          returnBucket: rr.returnBucket,
                        ),
                        icon: const Icon(Icons.menu, color: AppColors.primaryStrong),
                        tooltip: 'View Review History',
                      ),
                    ],
                  ),
                  if (line.priceUnit > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Price: ৳${line.priceUnit.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryStrong,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Subtotal: ৳${line.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (isSaleable) ...[
                        _buildQtyChip('Saleable', line.saleableQty, Colors.teal),
                        if (line.nonSaleableQty > 0 || (rr.isSegregationStage && auth.canDo(AppAction.mtReturnsSegregateSaleable)))
                          _buildQtyChip('Non-Saleable', line.nonSaleableQty, Colors.orange),
                      ] else if (rr.returnBucket == 'quality') ...[
                        _buildQtyChip('Quality', line.qualityQty, Colors.purple),
                        if (line.nonSaleableQty > 0 || (rr.isSegregationStage && auth.canDo(AppAction.mtReturnsSegregateQuality)))
                          _buildQtyChip('Non-Saleable', line.nonSaleableQty, Colors.orange),
                      ] else ...[
                        _buildQtyChip('Non-Saleable', line.nonSaleableQty, Colors.orange),
                        if (line.qualityQty > 0 || (rr.isSegregationStage && auth.canDo(AppAction.mtReturnsSegregateNonSaleable)))
                          _buildQtyChip('Quality', line.qualityQty, Colors.purple),
                      ],
                      _buildQtyChip('Total Qty', line.totalQty, AppColors.primaryStrong, isBold: true),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String? _getActionAccessKey(String? action, {String? state, String? backendKey}) {
    if (backendKey != null && backendKey.isNotEmpty) {
      return backendKey;
    }
    if (action == null) return null;
    switch (action.toLowerCase()) {
      case 'submit_dm':
      case 'action_submit_dm':
        return AppAction.mtReturnsSubmitDm;
      case 'submit_kas':
      case 'action_submit_kas':
        return AppAction.mtReturnsSubmitKas;
      case 'submit_supply_chain':
      case 'submit_sc':
      case 'action_submit_supply_chain':
        return AppAction.mtReturnsSubmitSupplyChain;
      case 'submit_qc':
      case 'action_submit_qc':
        return AppAction.mtReturnsSubmitQc;
      case 'submit_sales_operation':
      case 'submit_so':
      case 'action_submit_sales_operation':
        return AppAction.mtReturnsSubmitSalesOperation;
      case 'confirm':
      case 'action_confirm':
        return AppAction.mtReturnsConfirm;
      default:
        return null;
    }
  }

  bool _canUserPerformStage(MtReturnRequest rr, AuthProvider auth) {
    if (rr.isConfirmed) return false;
    final state = rr.state.toLowerCase();
    final groupCode = auth.user?.groupCode?.toLowerCase().trim();

    // Supply Chain role cannot act on QC stage once ticket has moved forward
    if (state == 'qc' && groupCode == 'sc') {
      return false;
    }

    final actions = rr.allowedActions;
    final nextAction = actions.nextAction;
    if (nextAction == null) return false;

    final actionKey = _getActionAccessKey(
      nextAction,
      state: rr.state,
      backendKey: actions.requiredAccessKey,
    );
    return actionKey == null || auth.canDo(actionKey);
  }

  Widget? _buildBottomActionBar(MtReturnRequest rr, AuthProvider auth, MtReturnProvider provider) {
    if (rr.isConfirmed) return null;

    final actions = rr.allowedActions;
    final nextAction = actions.nextAction;
    final nextLabel = actions.nextActionLabel ?? 'Submit Next Stage';

    final canPerformNext = _canUserPerformStage(rr, auth);

    if (!canPerformNext || nextAction == null) {
      return null;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: provider.isActionLoading
                ? null
                : () => _onExecuteAction(nextAction, nextLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: actions.canConfirm ? Colors.green.shade700 : AppColors.primaryStrong,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: provider.isActionLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    nextLabel,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String state, String label) {
    Color bg;
    Color fg;
    switch (state.toLowerCase()) {
      case 'confirmed':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        break;
      case 'sales_operation':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade800;
        break;
      case 'qc':
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade700;
        break;
      case 'supply_chain':
        bg = Colors.indigo.shade50;
        fg = Colors.indigo.shade700;
        break;
      case 'kas':
        bg = Colors.cyan.shade50;
        fg = Colors.cyan.shade800;
        break;
      case 'dm':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        break;
      default: // kao
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.4)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  Widget _buildTransferStateBadge(String state, String label) {
    final isDone = state == 'done';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDone ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDone ? Colors.green.shade300 : Colors.orange.shade300),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDone ? Colors.green.shade700 : Colors.orange.shade800,
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildQtyChip(String label, double qty, Color color, {bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        '$label: ${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
