import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:secondary_sales/data/models/delivery_item.dart';
import 'package:secondary_sales/data/models/contacts/res_zone.dart';
import 'package:secondary_sales/data/models/inventory/warehouse.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/features/sales/primary_sale_provider.dart';
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
  final List<String> _tabLabels = ['Pending Deliveries', 'Own Deliveries'];
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  List<DeliveryItem> _deliveries = [];
  String? _error;

  String _activeTab = 'pending';
  DateTime? _dateFromFilter;
  DateTime? _dateToFilter;

  int? _selectedZoneId;
  String? _selectedZoneName;
  int? _selectedLocationId;
  String? _selectedLocationName;
  int? _selectedOutletId;
  String? _selectedOutletName;
  List<ResZone> _zones = [];
  List<StockLocation> _locations = [];
  List<DeliveryOutletFilter> _outlets = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final tab = _tabs[_tabController.index];
        setState(() {
          _activeTab = tab;
        });
        _fetchDeliveries();
      }
    });
    _fetchDeliveries();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchDeliveries([String? query]) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final provider = context.read<PrimarySaleProvider>();
      final isMt = widget.businessType == 'mt' ||
          widget.moduleType == 'modern_trade' ||
          widget.moduleType == 'mt_primary';

      final result = await provider.apiService.getDeliveries(
        pageSize: 50,
        search: query ?? (_searchController.text.trim().isEmpty ? null : _searchController.text.trim()),
        type: isMt ? 'primary' : widget.moduleType,
        businessType: isMt ? 'mt' : (widget.businessType ?? 'gt'),
        segment: _activeTab,
        outletId: _selectedOutletId,
        zoneId: _selectedZoneId,
        locationId: _selectedLocationId,
        dateFrom: _dateFromFilter,
        dateTo: _dateToFilter,
      );
      if (mounted) {
        setState(() {
          _deliveries = result.items;
          if (result.zones.isNotEmpty || _zones.isEmpty) {
            _zones = result.zones;
          }
          if (result.locations.isNotEmpty || _locations.isEmpty) {
            _locations = result.locations;
          }
          if (result.outlets.isNotEmpty || _outlets.isEmpty) {
            _outlets = result.outlets;
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
        });
      }
    }
  }

  bool get _isMt =>
      widget.businessType == 'mt' ||
      widget.moduleType == 'modern_trade' ||
      widget.moduleType == 'mt_primary';

  bool get _hasActiveFilters => _isMt
      ? (_selectedOutletId != null ||
          _selectedZoneId != null ||
          _selectedLocationId != null ||
          (_dateFromFilter != null && _dateToFilter != null))
      : (_dateFromFilter != null && _dateToFilter != null);

  void _clearAllFilters() {
    setState(() {
      _selectedOutletId = null;
      _selectedOutletName = null;
      _selectedZoneId = null;
      _selectedZoneName = null;
      _selectedLocationId = null;
      _selectedLocationName = null;
      _dateFromFilter = null;
      _dateToFilter = null;
    });
    _fetchDeliveries();
  }

  void _clearOutletFilter() {
    setState(() {
      _selectedOutletId = null;
      _selectedOutletName = null;
    });
    _fetchDeliveries();
  }

  void _openOutletSearchModal() {
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
            final filteredOutlets = _outlets.where((out) {
              return out.name.toLowerCase().contains(query.toLowerCase()) ||
                  (out.ssCode != null &&
                      out.ssCode!.toLowerCase().contains(query.toLowerCase()));
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
                                'Select Outlet',
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
                              hintText: 'Search outlet by name or code...',
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
                        itemCount: filteredOutlets.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            final isSelected = _selectedOutletId == null;
                            return ListTile(
                              leading: const Icon(Icons.storefront_outlined),
                              title: const Text('All Outlets'),
                              trailing: isSelected
                                  ? const Icon(Icons.check,
                                      color: AppColors.primary)
                                  : null,
                              onTap: () {
                                Navigator.pop(ctx);
                                _clearOutletFilter();
                              },
                            );
                          }
                          final outlet = filteredOutlets[index - 1];
                          final isSelected = _selectedOutletId == outlet.id;
                          return ListTile(
                            leading: const Icon(Icons.store),
                            title: Text(outlet.name),
                            subtitle: outlet.ssCode != null
                                ? Text(outlet.ssCode!)
                                : null,
                            trailing: isSelected
                                ? const Icon(Icons.check,
                                    color: AppColors.primary)
                                : null,
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _selectedOutletId = outlet.id;
                                _selectedOutletName = outlet.name;
                              });
                              _fetchDeliveries();
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
    _fetchDeliveries();
  }

  void _clearLocationFilter() {
    setState(() {
      _selectedLocationId = null;
      _selectedLocationName = null;
    });
    _fetchDeliveries();
  }

  void _clearDateFilter() {
    setState(() {
      _dateFromFilter = null;
      _dateToFilter = null;
    });
    _fetchDeliveries();
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
      _fetchDeliveries();
    }
  }

  Future<void> _openFilterBottomSheet() async {
    int? tempZoneId = _selectedZoneId;
    int? tempLocationId = _selectedLocationId;
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
            return Padding(
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
                            tempLocationId = null;
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

                  // Location Filter
                  const Text(
                    'Stock Location',
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
                        value: tempLocationId,
                        hint: const Text('All Locations', style: TextStyle(fontSize: 14)),
                        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All Locations', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                          ),
                          ..._locations.map((loc) => DropdownMenuItem<int?>(
                                value: loc.id,
                                child: Text(
                                  loc.completeName ?? loc.name,
                                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )),
                        ],
                        onChanged: (val) {
                          setSheetState(() {
                            tempLocationId = val;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Date Range Filter
                  const Text(
                    'Date Range',
                    style: TextStyle(
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
                                  : 'Select date range',
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

                          _selectedLocationId = tempLocationId;
                          _selectedLocationName = tempLocationId != null
                              ? _locations.firstWhere((l) => l.id == tempLocationId, orElse: () => StockLocation(id: tempLocationId!, name: 'Loc $tempLocationId')).name
                              : null;

                          _dateFromFilter = tempDateFrom;
                          _dateToFilter = tempDateTo;
                        });
                        Navigator.pop(ctx);
                        _fetchDeliveries();
                      },
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final int totalCount = _deliveries.length;
    final int pendingCount = _deliveries
        .where((d) => d.state == 'waiting' || d.state == 'confirmed' || d.state == 'assigned')
        .length;
    final int deliveredCount = _deliveries.where((d) => d.state == 'done').length;

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
          tabs: _tabLabels.map((label) {
            return Tab(text: label);
          }).toList(),
        ),
      ),
      body: Column(
        children: [
          // Stat cards header (Matching Leave Dashboard 1:1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                _buildStatCard('Total', '$totalCount', Colors.indigo),
                const SizedBox(width: 8),
                _buildStatCard('Pending', '$pendingCount', Colors.amber[800]!),
                const SizedBox(width: 8),
                _buildStatCard('Delivered', '$deliveredCount', Colors.green),
              ],
            ),
          ),
          // Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 8.0),
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
                                      _fetchDeliveries();
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          style: const TextStyle(fontSize: 14),
                          onSubmitted: (val) => _fetchDeliveries(val.trim().isEmpty ? null : val.trim()),
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
                                ? 'Filter by Zone, Location & Date'
                                : 'Filter by Date Range',
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
                      if (_isMt && _selectedOutletName != null)
                        Chip(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                          labelStyle: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                          avatar: const Icon(Icons.storefront_outlined, size: 14, color: AppColors.primary),
                          label: Text('Outlet: $_selectedOutletName'),
                          deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.primary),
                          onDeleted: _clearOutletFilter,
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
                      if (_isMt && _selectedLocationName != null)
                        Chip(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                          labelStyle: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                          avatar: const Icon(Icons.warehouse_outlined, size: 14, color: AppColors.primary),
                          label: Text('Loc: $_selectedLocationName'),
                          deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.primary),
                          onDeleted: _clearLocationFilter,
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
                          label: Text('${ssFormatDate(_dateFromFilter!)} - ${ssFormatDate(_dateToFilter!)}'),
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
          // Left-to-Right Scrollable Outlet Filter Bar (Matching Category Bar pattern)
          if (_isMt && _outlets.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  InkWell(
                    onTap: _openOutletSearchModal,
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
                            'Outlet',
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
                        itemCount: _outlets.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            final bool isSelected = _selectedOutletId == null;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: const Text('All Outlets'),
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
                                  _clearOutletFilter();
                                },
                              ),
                            );
                          }
                          final outlet = _outlets[index - 1];
                          final bool isSelected = _selectedOutletId == outlet.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(outlet.name),
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
                                  _selectedOutletId = outlet.id;
                                  _selectedOutletName = outlet.name;
                                });
                                _fetchDeliveries();
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
          // Deliveries List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchDeliveries(),
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
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: _deliveries.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
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

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
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
        final isMt = widget.businessType == 'mt' ||
            widget.moduleType == 'modern_trade' ||
            widget.moduleType == 'mt_primary';
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
          _fetchDeliveries();
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
                    Text(
                      'Delivery Man: ${delivery.deliveryManName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
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
                    Text(
                      'Zone: ${delivery.zoneName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
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
}
