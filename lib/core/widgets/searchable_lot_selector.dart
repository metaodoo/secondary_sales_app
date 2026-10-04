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

/// Generic Lot picker with a searchable bottom sheet.
class GenericSearchableLotSelector<T> extends StatelessWidget {
  final T? selectedItem;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T item) getLabel;
  final String? Function(T item)? getSubtitle;
  final String? Function(T item)? getBadgeText;
  final Color? Function(T item)? getBadgeColor;
  final bool isReadOnly;
  final String hintText;
  final String modalTitle;
  final bool allowClear;
  final String clearLabel;

  const GenericSearchableLotSelector({
    super.key,
    required this.selectedItem,
    required this.items,
    required this.onChanged,
    required this.getLabel,
    this.getSubtitle,
    this.getBadgeText,
    this.getBadgeColor,
    this.isReadOnly = false,
    this.hintText = 'Search & Select Lot...',
    this.modalTitle = 'Select Lot Number',
    this.allowClear = false,
    this.clearLabel = 'No Lot / Standard',
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedItem != null;
    final labelText = hasSelection ? getLabel(selectedItem as T) : hintText;

    return InkWell(
      onTap: isReadOnly ? null : () => _showSearchModal(context),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isReadOnly ? Colors.grey[100] : Colors.white,
          border: Border.all(color: const Color(0xFFDDE6F2)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                labelText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: hasSelection ? FontWeight.w600 : FontWeight.normal,
                  color: hasSelection ? Colors.black87 : AppColors.textSecondary,
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
    showGenericSearchableLotPicker<T>(
      context,
      items: items,
      currentItem: selectedItem,
      getLabel: getLabel,
      getSubtitle: getSubtitle,
      getBadgeText: getBadgeText,
      getBadgeColor: getBadgeColor,
      title: modalTitle,
      allowClear: allowClear,
      clearLabel: clearLabel,
    ).then((selected) {
      onChanged(selected);
    });
  }
}

/// Convenience wrapper for TransferLot.
class SearchableLotSelector extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GenericSearchableLotSelector<TransferLot>(
      selectedItem: selectedLot,
      items: lots,
      onChanged: onChanged,
      isReadOnly: isReadOnly,
      getLabel: (lot) => lot.lotName,
      modalTitle: 'Select Lot Number',
    );
  }
}

/// Standalone modal bottom sheet helper for searchable lot selection.
Future<T?> showGenericSearchableLotPicker<T>(
  BuildContext context, {
  required List<T> items,
  T? currentItem,
  required String Function(T item) getLabel,
  String? Function(T item)? getSubtitle,
  String? Function(T item)? getBadgeText,
  Color? Function(T item)? getBadgeColor,
  String title = 'Select Lot Number',
  String searchHint = 'Type to filter (e.g. lot00001)...',
  bool allowClear = false,
  String clearLabel = 'No Lot / Standard',
}) {
  return showModalBottomSheet<T?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _GenericLotSearchBottomSheet<T>(
      items: items,
      currentItem: currentItem,
      getLabel: getLabel,
      getSubtitle: getSubtitle,
      getBadgeText: getBadgeText,
      getBadgeColor: getBadgeColor,
      title: title,
      searchHint: searchHint,
      allowClear: allowClear,
      clearLabel: clearLabel,
    ),
  );
}

class _GenericLotSearchBottomSheet<T> extends StatefulWidget {
  final List<T> items;
  final T? currentItem;
  final String Function(T item) getLabel;
  final String? Function(T item)? getSubtitle;
  final String? Function(T item)? getBadgeText;
  final Color? Function(T item)? getBadgeColor;
  final String title;
  final String searchHint;
  final bool allowClear;
  final String clearLabel;

  const _GenericLotSearchBottomSheet({
    required this.items,
    this.currentItem,
    required this.getLabel,
    this.getSubtitle,
    this.getBadgeText,
    this.getBadgeColor,
    required this.title,
    required this.searchHint,
    required this.allowClear,
    required this.clearLabel,
  });

  @override
  State<_GenericLotSearchBottomSheet<T>> createState() =>
      _GenericLotSearchBottomSheetState<T>();
}

class _GenericLotSearchBottomSheetState<T>
    extends State<_GenericLotSearchBottomSheet<T>> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounceTimer;
  List<T> _filteredItems = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _filteredItems = List.from(widget.items);
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
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      final q = query.trim().toLowerCase();
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        if (q.isEmpty) {
          _filteredItems = List.from(widget.items);
        } else {
          final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
          _filteredItems = widget.items.where((item) {
            final label = widget.getLabel(item).toLowerCase();
            final subtitle = widget.getSubtitle?.call(item)?.toLowerCase() ?? '';
            final fullText = '$label $subtitle';
            return words.every((w) => fullText.contains(w));
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
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              hintText: widget.searchHint,
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
          if (widget.allowClear)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: const Icon(Icons.remove_circle_outline, color: Colors.grey, size: 20),
              title: Text(
                widget.clearLabel,
                style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              onTap: () => Navigator.pop(context, null),
            ),
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filteredItems.isEmpty)
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
                itemCount: _filteredItems.length,
                separatorBuilder: (_, index) => const Divider(
                  height: 1,
                  color: AppColors.borderSoft,
                ),
                itemBuilder: (context, index) {
                  final item = _filteredItems[index];
                  final isSelected = widget.currentItem == item;
                  final label = widget.getLabel(item);
                  final subtitle = widget.getSubtitle?.call(item);
                  final badgeText = widget.getBadgeText?.call(item);
                  final badgeColor = widget.getBadgeColor?.call(item) ?? Colors.blue;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primaryStrong
                                  : AppColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (badgeText != null && badgeText.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: subtitle != null && subtitle.isNotEmpty
                        ? Text(
                            subtitle,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          )
                        : null,
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
                    onTap: () => Navigator.pop(context, item),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
