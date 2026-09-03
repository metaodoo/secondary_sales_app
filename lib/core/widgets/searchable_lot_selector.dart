import 'dart:async';

import 'package:flutter/material.dart';

import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/data/models/inventory/virtual_transfer.dart';

/// Lot picker with a searchable bottom sheet, shared by all three return types.
///
/// Lives here rather than beside one screen because the Saleable/QC screen and
/// the Non-Saleable screen are separate files: the picker was written once for
/// the former, and the latter was left on a plain `DropdownButtonFormField`,
/// which is unusable once a product has more than a handful of lots. A shared
/// widget is what keeps the three flows in step by construction rather than by
/// remembering to copy a change twice.

class SearchableLotSelector extends StatefulWidget {
  final TransferLot? selectedLot;
  final List<TransferLot> lots;
  final ValueChanged<TransferLot?> onChanged;
  final bool isReadOnly;

  const SearchableLotSelector({
    super.key,
    required this.selectedLot,
    required this.lots,
    required this.onChanged,
    this.isReadOnly = false,
  });

  @override
  State<SearchableLotSelector> createState() => _SearchableLotSelectorState();
}

class _SearchableLotSelectorState extends State<SearchableLotSelector> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.isReadOnly ? null : () => _showSearchModal(context),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: widget.isReadOnly ? Colors.grey[100] : Colors.white,
          border: Border.all(color: const Color(0xFFDDE6F2)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.selectedLot?.lotName ?? 'Search & Select Lot...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.selectedLot != null
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: widget.selectedLot != null
                      ? Colors.black87
                      : AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.arrow_drop_down,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchModal(BuildContext context) {
    showModalBottomSheet<TransferLot>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LotSearchBottomSheet(
        lots: widget.lots,
        currentLot: widget.selectedLot,
      ),
    ).then((selected) {
      if (selected != null && mounted) {
        widget.onChanged(selected);
      }
    });
  }
}

class _LotSearchBottomSheet extends StatefulWidget {
  final List<TransferLot> lots;
  final TransferLot? currentLot;

  const _LotSearchBottomSheet({
    required this.lots,
    this.currentLot,
  });

  @override
  State<_LotSearchBottomSheet> createState() => _LotSearchBottomSheetState();
}

class _LotSearchBottomSheetState extends State<_LotSearchBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;
  List<TransferLot> _filteredLots = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _filteredLots = List.from(widget.lots);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() => _isSearching = true);
    _debounceTimer?.cancel();
    // 300ms Search Debouncing as requested
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final q = query.trim().toLowerCase();
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        if (q.isEmpty) {
          _filteredLots = List.from(widget.lots);
        } else {
          _filteredLots = widget.lots.where((lot) {
            return lot.lotName.toLowerCase().contains(q);
          }).toList();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.qr_code_2_rounded,
                color: AppColors.primaryStrong,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Select Lot Number',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Type to filter (e.g. lot00001)...',
              prefixIcon: const Icon(Icons.search, color: AppColors.primaryStrong),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _controller.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.borderSoft),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.primaryStrong,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filteredLots.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No matching lots found for "${_controller.text}"',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: _filteredLots.length,
                separatorBuilder: (_, index) => const Divider(
                  height: 1,
                  color: AppColors.borderSoft,
                ),
                itemBuilder: (context, index) {
                  final lot = _filteredLots[index];
                  final isSelected = widget.currentLot?.lotId == lot.lotId;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    title: Text(
                      lot.lotName,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? AppColors.primaryStrong
                            : AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: AppColors.primaryStrong,
                            size: 20,
                          )
                        : const Icon(
                            Icons.chevron_right,
                            color: AppColors.borderSoft,
                            size: 18,
                          ),
                    onTap: () => Navigator.pop(context, lot),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
