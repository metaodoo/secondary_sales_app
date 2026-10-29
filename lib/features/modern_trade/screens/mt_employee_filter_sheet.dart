import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/data/api/api_service.dart';

class MtEmployeeFilterSheet extends StatefulWidget {
  final int? selectedEmployeeId;
  final List<Map<String, dynamic>>? extraEmployees;
  final Function(int? id, String? name) onSelected;

  const MtEmployeeFilterSheet({
    super.key,
    required this.selectedEmployeeId,
    this.extraEmployees,
    required this.onSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required int? selectedEmployeeId,
    List<Map<String, dynamic>>? extraEmployees,
    required Function(int? id, String? name) onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MtEmployeeFilterSheet(
        selectedEmployeeId: selectedEmployeeId,
        extraEmployees: extraEmployees,
        onSelected: onSelected,
      ),
    );
  }

  @override
  State<MtEmployeeFilterSheet> createState() => _MtEmployeeFilterSheetState();
}

class _MtEmployeeFilterSheetState extends State<MtEmployeeFilterSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _subordinates = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSubordinates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSubordinates() async {
    final Map<int, Map<String, dynamic>> empMap = {};

    // Pre-populate with any extra employees passed from loaded records
    if (widget.extraEmployees != null) {
      for (final e in widget.extraEmployees!) {
        final eid = int.tryParse('${e['id']}');
        final ename = e['name']?.toString() ?? '';
        if (eid != null && eid > 0 && ename.isNotEmpty) {
          empMap[eid] = {
            'id': eid,
            'name': ename,
            'work_email': e['work_email']?.toString() ?? '',
          };
        }
      }
    }

    try {
      final res = await ApiService.instance.getMyTeam();
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>? ?? {};
        final list = data['my_team'] as List? ?? [];
        for (final item in list) {
          if (item is Map) {
            final id = int.tryParse('${item['id']}');
            final name = item['name']?.toString() ?? '';
            if (id != null && id > 0 && name.isNotEmpty) {
              empMap[id] = {
                'id': id,
                'name': name,
                'work_email': item['work_email']?.toString() ?? '',
              };
            }
          }
        }
      } else if (empMap.isEmpty) {
        _error = res['message'] ?? 'Failed to load team directory.';
      }
    } catch (e) {
      if (empMap.isEmpty) {
        _error = e.toString();
      }
    } finally {
      if (mounted) {
        final sortedList = empMap.values.toList()
          ..sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
        setState(() {
          _subordinates = sortedList;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _subordinates.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final email = (s['work_email'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.people_alt_outlined, color: AppColors.primaryStrong, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Filter by Employee',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryStrong,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search employee name...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceTint,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderSoft),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderSoft),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && _subordinates.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: widget.selectedEmployeeId == null
                                    ? AppColors.primaryStrong
                                    : Colors.grey.shade200,
                                radius: 16,
                                child: Icon(
                                  Icons.group,
                                  size: 18,
                                  color: widget.selectedEmployeeId == null
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                              title: const Text(
                                'All Team Members',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              trailing: widget.selectedEmployeeId == null
                                  ? const Icon(Icons.check, color: AppColors.primaryStrong, size: 20)
                                  : null,
                              onTap: () {
                                widget.onSelected(null, null);
                                Navigator.pop(context);
                              },
                            ),
                            if (filtered.isEmpty && _searchQuery.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Center(
                                  child: Text(
                                    'No team members match search',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  ),
                                ),
                              )
                            else if (filtered.isEmpty && !_isLoading)
                              const Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Center(
                                  child: Text(
                                    'No subordinates found',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  ),
                                ),
                              )
                            else
                              ...filtered.map((sub) {
                                final subId = int.tryParse('${sub['id']}') ?? 0;
                                final subName = sub['name']?.toString() ?? 'Unnamed';
                                final isSelected = widget.selectedEmployeeId == subId;

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isSelected
                                        ? AppColors.primarySoft
                                        : AppColors.surfaceTint,
                                    radius: 16,
                                    child: Text(
                                      subName.isNotEmpty ? subName.characters.first.toUpperCase() : '?',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: isSelected ? AppColors.primaryStrong : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    subName,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? AppColors.primaryStrong : AppColors.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check, color: AppColors.primaryStrong, size: 20)
                                      : null,
                                  onTap: () {
                                    widget.onSelected(subId, subName);
                                    Navigator.pop(context);
                                  },
                                );
                              }),
                          ],
                        ),
            ),
          ],
        );
      },
    );
  }
}
