import 'dart:async';
import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/data/models/delivery_item.dart';
import 'package:secondary_sales/data/models/contacts/res_zone.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/features/sales/primary_sale_provider.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/features/sales/screens/validate_delivery_screen.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class DeliveriesListScreen extends StatefulWidget {
  final String moduleType;
  final String? businessType;
  const DeliveriesListScreen({
    super.key,
    this.moduleType = 'primary',
    this.businessType,
  });

  @override
  State<DeliveriesListScreen> createState() => _DeliveriesListScreenState();
}

class _DeliveriesListScreenState extends State<DeliveriesListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['pending', 'own'];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 50;

  Timer? _searchDebounce;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  List<DeliveryItem> _deliveries = [];
  String? _error;

  int _pendingCount = 0;
  int _deliveredCount = 0;

  String _activeTab = 'pending';
  DateTime? _dateFromFilter;
  DateTime? _dateToFilter;

  int? _selectedZoneId;
  String? _selectedZoneName;
  int? _selectedAreaId;
  String? _selectedAreaName;
  List<ResZone> _zones = [];
  List<DeliveryAreaFilter> _areas = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final tab = _tabs[_tabController.index];
        if (_activeTab != tab) {
          setState(() {
            _activeTab = tab;
          });
          _fetchDeliveries(reset: true);
        }
      }
    });
    _fetchDeliveries(reset: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _fetchDeliveries(reset: true);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _fetchDeliveries();
    }
  }

  Future<void> _fetchDeliveries({bool reset = false, String? query}) async {
    if (reset) {
      _page = 1;
      _hasMore = true;
      _isLoadingMore = false;
    }
    if (!reset && (!_hasMore || _isLoadingMore)) {
      return;
    }

    if (!mounted) return;
    setState(() {
      if (reset) {
        _isLoading = true;
        _error = null;
      } else {
        _isLoadingMore = true;
      }
    });
    try {
      final provider = context.read<PrimarySaleProvider>();
      final isMt = _isMt;

      final result = await provider.apiService.getDeliveries(
        page: _page,
        pageSize: _pageSize,
        search: query ?? (_searchController.text.trim().isEmpty ? null : _searchController.text.trim()),
        type: isMt ? 'primary' : widget.moduleType,
        businessType: isMt ? 'mt' : (widget.businessType ?? 'gt'),
        segment: _activeTab,
        areaId: _selectedAreaId,
        zoneId: _selectedZoneId,
        dateFrom: _dateFromFilter,
        dateTo: _dateToFilter,
      );
      if (mounted) {
        setState(() {
          if (reset) {
            _deliveries = result.items;
          } else {
            _deliveries.addAll(result.items);
          }
          _pendingCount = result.pendingCount;
          _deliveredCount = result.deliveredCount;
          _hasMore = result.items.length == _pageSize;
          if (_hasMore) {
            _page += 1;
          }
          if (result.zones.isNotEmpty || _zones.isEmpty) {
            _zones = result.zones;
          }
          if (result.areas.isNotEmpty || _areas.isEmpty) {
            _areas = result.areas;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  bool get _isMt {
    if (widget.businessType == 'mt' ||
        widget.moduleType == 'modern_trade' ||
        widget.moduleType == 'mt_primary') {
      return true;
    }
    try {
      final auth = context.read<AuthProvider>();
      return auth.isModernTrade;
    } catch (_) {
      return false;
    }
  }

  bool get _hasActiveFilters => _isMt
      ? (_selectedAreaId != null ||
          _selectedZoneId != null ||
          (_dateFromFilter != null && _dateToFilter != null))
      : (_dateFromFilter != null && _dateToFilter != null);

  void _clearAllFilters() {
    setState(() {
      _selectedAreaId = null;
      _selectedAreaName = null;
      _selectedZoneId = null;
      _selectedZoneName = null;
      _dateFromFilter = null;
      _dateToFilter = null;
    });
    _fetchDeliveries(reset: true);
  }

  void _clearAreaFilter() {
    setState(() {
      _selectedAreaId = null;
      _selectedAreaName = null;
    });
    _fetchDeliveries(reset: true);
  }

  void _openAreaSearchModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredAreas = _areas.where((a) {
              return a.name.toLowerCase().contains(query.toLowerCase());
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    Padding(
                       padding: const EdgeInsets.all(16.0),
                       child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Select Area',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            onChanged: (val) {
                              setModalState(() {
                                query = val.trim();
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Search area by name...',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: AppColors.background,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filteredAreas.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            final isSelected = _selectedAreaId == null;
                            return ListTile(
                              leading: const Icon(Icons.location_city_outlined),
                              title: const Text('All Areas'),
                              trailing: isSelected
                                  ? const Icon(Icons.check,
                                      color: AppColors.primary)
                                  : null,
                              onTap: () {
                                Navigator.pop(ctx);
                                _clearAreaFilter();
                              },
                            );
                          }
                          final area = filteredAreas[index - 1];
                          final isSelected = _selectedAreaId == area.id;
                          return ListTile(
                            leading: const Icon(Icons.location_city),
                            title: Text(area.name),
                            trailing: isSelected
                                ? const Icon(Icons.check,
                                    color: AppColors.primary)
                                : null,
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _selectedAreaId = area.id;
                                _selectedAreaName = area.name;
                              });
                              _fetchDeliveries(reset: true);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _clearZoneFilter() {
    setState(() {
      _selectedZoneId = null;
      _selectedZoneName = null;
    });
    _fetchDeliveries(reset: true);
  }


  void _clearDateFilter() {
    setState(() {
      _dateFromFilter = null;
      _dateToFilter = null;
    });
    _fetchDeliveries(reset: true);
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _dateFromFilter != null && _dateToFilter != null
          ? DateTimeRange(start: _dateFromFilter!, end: _dateToFilter!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateFromFilter = picked.start;
        _dateToFilter = picked.end;
      });
      _fetchDeliveries(reset: true);
    }
  }

  Future<void> _openFilterBottomSheet() async {
    int? tempZoneId = _selectedZoneId;
    DateTime? tempDateFrom = _dateFromFilter;
    DateTime? tempDateTo = _dateToFilter;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Deliveries',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            tempZoneId = null;
                            tempDateFrom = null;
                            tempDateTo = null;
                          });
                        },
                        child: const Text(
                          'Reset',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  const SizedBox(height: 8),

                  // Zone Filter
                  const Text(
                    'Zone',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        isExpanded: true,
                        value: tempZoneId,
                        hint: const Text('All Zones', style: TextStyle(fontSize: 14)),
                        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All Zones', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                          ),
                          ..._zones.map((z) => DropdownMenuItem<int?>(
                                value: z.id,
                                child: Text(z.name, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                              )),
                        ],
                        onChanged: (val) {
                          setSheetState(() {
                            tempZoneId = val;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Date Range Filter
                  Text(
                    _activeTab == 'pending'
                        ? 'Scheduled Date Range'
                        : 'Effective Date Range',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final DateTimeRange? picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                        initialDateRange: tempDateFrom != null && tempDateTo != null
                            ? DateTimeRange(start: tempDateFrom!, end: tempDateTo!)
                            : null,
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: AppColors.primary,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: AppColors.textPrimary,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setSheetState(() {
                          tempDateFrom = picked.start;
                          tempDateTo = picked.end;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderSoft),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month, size: 20, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              (tempDateFrom != null && tempDateTo != null)
                                  ? '${ssFormatDate(tempDateFrom!)} - ${ssFormatDate(tempDateTo!)}'
                                  : (_activeTab == 'pending'
                                      ? 'Select scheduled date range'
                                      : 'Select effective date range'),
                              style: TextStyle(
                                fontSize: 14,
                                color: (tempDateFrom != null)
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (tempDateFrom != null)
                            GestureDetector(
                              onTap: () {
                                setSheetState(() {
                                  tempDateFrom = null;
                                  tempDateTo = null;
                                });
                              },
                              child: const Icon(Icons.close, size: 18, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedZoneId = tempZoneId;
                          _selectedZoneName = tempZoneId != null
                              ? _zones.firstWhere((z) => z.id == tempZoneId, orElse: () => ResZone(id: tempZoneId!, name: 'Zone $tempZoneId')).name
                              : null;

                          _dateFromFilter = tempDateFrom;
                          _dateToFilter = tempDateTo;
                        });
                        Navigator.pop(ctx);
                        _fetchDeliveries(reset: true);
                      },
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.textPrimary,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Deliveries',
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
            child: ProfileAvatar(currentDestinationLabel: 'Delivery'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(
              text: _pendingCount > 0
                  ? 'Pending (${_formatCount(_pendingCount)})'
                  : 'Pending Deliveries',
            ),
            Tab(
              text: _deliveredCount > 0
                  ? 'Delivered (${_formatCount(_deliveredCount)})'
                  : 'Own Deliveries',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) ...[
                  ErrorPanel(_error!),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    // Search Field
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderSoft),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search ref, outlet or delivery man...',
                            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                            prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                                    onPressed: () {
                                      _searchController.clear();
                                      _fetchDeliveries(reset: true);
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          style: const TextStyle(fontSize: 14),
                          onChanged: _onSearchChanged,
                          onSubmitted: (val) => _fetchDeliveries(reset: true, query: val.trim().isEmpty ? null : val.trim()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Filter Trigger Button
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: _hasActiveFilters
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _hasActiveFilters
                                  ? AppColors.primary
                                  : AppColors.borderSoft,
                            ),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.filter_alt_outlined,
                              color: _hasActiveFilters
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            tooltip: _isMt
                                ? (_activeTab == 'pending'
                                    ? 'Filter by Zone & Scheduled Date'
                                    : 'Filter by Zone & Effective Date')
                                : (_activeTab == 'pending'
                                    ? 'Filter by Scheduled Date'
                                    : 'Filter by Effective Date'),
                            onPressed: _isMt
                                ? _openFilterBottomSheet
                                : _selectDateRange,
                          ),
                        ),
                        if (_hasActiveFilters)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                // Active Filters Chips
                if (_hasActiveFilters) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (_isMt && _selectedAreaName != null)
                        Chip(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                          labelStyle: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                          avatar: const Icon(Icons.location_city_outlined, size: 14, color: AppColors.primary),
                          label: Text('Area: $_selectedAreaName'),
                          deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.primary),
                          onDeleted: _clearAreaFilter,
                        ),
                      if (_isMt && _selectedZoneName != null)
                        Chip(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                          labelStyle: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                          avatar: const Icon(Icons.location_on_outlined, size: 14, color: AppColors.primary),
                          label: Text('Zone: $_selectedZoneName'),
                          deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.primary),
                          onDeleted: _clearZoneFilter,
                        ),
                      if (_dateFromFilter != null && _dateToFilter != null)
                        Chip(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                          labelStyle: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                          avatar: const Icon(Icons.calendar_month, size: 14, color: AppColors.primary),
                          label: Text(
                            '${_activeTab == 'pending' ? 'Schedule' : 'Effective'}: ${ssFormatDate(_dateFromFilter!)} - ${ssFormatDate(_dateToFilter!)}',
                          ),
                          deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.primary),
                          onDeleted: _clearDateFilter,
                        ),
                      GestureDetector(
                        onTap: _clearAllFilters,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text(
                            'Clear All',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Left-to-Right Scrollable Area Filter Bar
          if (_isMt) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  InkWell(
                    onTap: _openAreaSearchModal,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search, size: 16, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text(
                            'Area',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.zero,
                        itemCount: _areas.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            final bool isSelected = _selectedAreaId == null;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: const Text('All Areas'),
                                selected: isSelected,
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                                backgroundColor: Colors.white,
                                side: BorderSide(
                                  color: isSelected ? AppColors.primary : AppColors.borderSoft,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                onSelected: (_) {
                                  _clearAreaFilter();
                                },
                              ),
                            );
                          }
                          final area = _areas[index - 1];
                          final bool isSelected = _selectedAreaId == area.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(area.name),
                              selected: isSelected,
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: isSelected ? AppColors.primary : AppColors.borderSoft,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              onSelected: (_) {
                                setState(() {
                                  _selectedAreaId = area.id;
                                  _selectedAreaName = area.name;
                                });
                                _fetchDeliveries(reset: true);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Summary Metrics Cards (Full unpaginated counts)
          _buildSummaryCards(),
          // Deliveries List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchDeliveries(reset: true),
              child: _isLoading && _deliveries.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _deliveries.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 100),
                            _buildEmptyState(),
                          ],
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: _deliveries.length + (_isLoadingMore ? 1 : 0),
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index >= _deliveries.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            final delivery = _deliveries[index];
                            return _buildDeliveryCard(delivery);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.local_shipping_outlined,
          size: 64,
          color: AppColors.textSecondary.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 16),
        const Text(
          'No Deliveries Found',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'No delivery orders match the selected filters.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildDeliveryCard(DeliveryItem delivery) {
    String badgeText = delivery.state.toUpperCase();
    Color badgeColor = AppColors.borderMuted;
    Color badgeTextColor = AppColors.textSecondary;

    if (delivery.state == 'done') {
      badgeText = 'DELIVERED';
      badgeColor = const Color(0xFFDCFCE7);
      badgeTextColor = const Color(0xFF15803D);
    } else if (delivery.state == 'cancel') {
      badgeText = 'CANCELLED';
      badgeColor = const Color(0xFFFEE2E2);
      badgeTextColor = const Color(0xFFB91C1C);
    } else if (delivery.state == 'assigned') {
      badgeText = 'READY';
      badgeColor = AppColors.primaryTint;
      badgeTextColor = const Color(0xFF1D4ED8);
    } else if (delivery.state == 'waiting' || delivery.state == 'confirmed') {
      badgeText = 'WAITING';
      badgeColor = const Color(0xFFFEF3C7);
      badgeTextColor = const Color(0xFFB45309);
    }

    final dateStr = _formatDate(delivery.createdDate);
    final estStr = _formatDate(delivery.scheduledDate);

    return InkWell(
      onTap: () {
        if (delivery.saleId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot view details: Missing Sale Order ID'),
            ),
          );
          return;
        }
        final isMt = _isMt;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ValidateDeliveryScreen(
              orderId: delivery.saleId!,
              orderName: delivery.saleName ?? '',
              pickingId: delivery.id,
              pickingName: delivery.name,
              pickingState: delivery.state,
              saleType: isMt ? 'primary' : widget.moduleType,
              businessType: isMt ? 'mt' : (widget.businessType ?? 'gt'),
            ),
          ),
        ).then((_) {
          _fetchDeliveries(reset: true);
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          delivery.name,
                          style: const TextStyle(
                            color: Color(0xFF1D4ED8),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (delivery.saleName != null &&
                            delivery.saleName!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Order Ref: ${delivery.saleName}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeTextColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                delivery.partnerName ?? 'Unknown Partner',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (delivery.deliveryManName != null && delivery.deliveryManName!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person_pin_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Delivery Man: ${delivery.deliveryManName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (delivery.zoneName != null && delivery.zoneName!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Zone: ${delivery.zoneName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              const Divider(color: AppColors.borderSoft),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Created Date',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          delivery.state == 'done'
                              ? 'Delivery Date'
                              : 'Est. Delivery',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          delivery.state == 'done'
                              ? _formatDate(delivery.dateDone)
                              : estStr,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatCount(int count) {
    return count.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Widget _buildSummaryCards() {
    final bool isPending = _activeTab == 'pending';
    final int count = isPending ? _pendingCount : _deliveredCount;
    final String title = isPending ? 'Pending Deliveries' : 'Delivered Orders';
    final String subtitle = isPending
        ? (_selectedAreaName != null
            ? 'Area: $_selectedAreaName'
            : 'Matching active filters')
        : 'Delivered by me';
    final Color accentColor = isPending
        ? const Color(0xFFD97706)
        : const Color(0xFF16A34A);
    final Color bgColor = isPending
        ? const Color(0xFFFFFBEB)
        : const Color(0xFFF0FDF4);
    final IconData icon = isPending
        ? Icons.hourglass_top_rounded
        : Icons.check_circle_outline_rounded;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 24,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                _formatCount(count),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
