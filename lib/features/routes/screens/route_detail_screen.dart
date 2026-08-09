import 'package:flutter/material.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/data/models/routes/route.dart';
import 'package:secondary_sales/features/routes/route_provider.dart';
import 'package:secondary_sales/core/services/location_service.dart';
import 'package:secondary_sales/features/visits/screens/route_sessions_screen.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';
import 'package:secondary_sales/core/access/access_resources.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';

class RouteDetailScreen extends StatefulWidget {
  final int routeId;

  const RouteDetailScreen({super.key, required this.routeId});

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RouteProvider>().fetchRouteDetail(widget.routeId);
    });
  }

  void _openAddOutletSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AddOutletBottomSheet(routeId: widget.routeId);
      },
    );
  }

  Future<void> _confirmRemoveOutlet(int routeId, RouteOutlet outlet) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Outlet'),
        content: Text(
          'Are you sure you want to remove ${outlet.name} from this route?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await context.read<RouteProvider>().removeOutletFromRoute(
        routeId,
        outlet.id,
      );
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${outlet.name} removed from route.')),
          );
        } else {
          final err = context.read<RouteProvider>().error;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err ?? 'Failed to remove outlet')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RouteProvider>();
    final route = provider.activeRoute;
    final isLoading = provider.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          route?.name ?? 'Route Details',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: isLoading && route == null
          ? const Center(child: CircularProgressIndicator())
          : route == null
          ? const Padding(
              padding: EdgeInsets.all(16.0),
              child: EmptyPanel(message: 'Route details could not be loaded.'),
            )
          : RefreshIndicator(
              onRefresh: () => provider.fetchRouteDetail(widget.routeId),
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  if (provider.error != null) ErrorPanel(provider.error!),

                  // Route Header Info Card
                  _buildRouteHeaderCard(route),

                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RouteSessionsScreen(route: route),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history),
                    label: const Text('View Route Visits'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryStrong,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Assigned Sales Officers Section
                  _buildAssignedOfficersCard(route),

                  const SizedBox(height: 20),

                  // Assigned Outlets Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.storefront_outlined,
                            color: AppColors.textPrimary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ASSIGNED OUTLETS (${route.outlets.length})',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      if (context.watch<AuthProvider>().canDo(
                        AppAction.routeAddOutlet,
                      ))
                        TextButton.icon(
                          onPressed: _openAddOutletSheet,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Outlet'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryStrong,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Outlets List
                  route.outlets.isEmpty
                      ? const EmptyPanel(
                          message: 'No outlets assigned to this route yet.',
                        )
                      : Column(
                          children: route.outlets.map((outlet) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: ssPanelDecoration(),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.store,
                                    color: Color(0xFF3B82F6),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        outlet.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (outlet.sequence > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'Seq: ${outlet.sequence}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (outlet.mobile != null ||
                                          outlet.phone != null)
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.phone_outlined,
                                              size: 13,
                                              color: AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              outlet.mobile ??
                                                  outlet.phone ??
                                                  '',
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      const SizedBox(height: 4),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.location_on_outlined,
                                            size: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              _buildOutletAddress(outlet),
                                              style: const TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 13,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Color(0xFFEF4444),
                                  ),
                                  onPressed: () =>
                                      _confirmRemoveOutlet(route.id, outlet),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
    );
  }

  String _buildOutletAddress(RouteOutlet outlet) {
    final parts = [
      outlet.street,
      outlet.street2,
      outlet.city,
    ].where((p) => p != null && p.trim().isNotEmpty);
    return parts.isEmpty ? 'No address specified' : parts.join(', ');
  }

  Widget _buildRouteHeaderCard(RouteModel route) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ssPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: route.active
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  route.active ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: route.active
                        ? const Color(0xFF059669)
                        : const Color(0xFFDC2626),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            route.name,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          const Text(
            'Primary Dealer / Distributor',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            route.distributorName ?? 'No primary dealer assigned',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedOfficersCard(RouteModel route) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ssPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ASSIGNED SALES OFFICERS',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          route.employees.isEmpty
              ? const Text(
                  'No Sales Officers assigned.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: route.employees.length,
                  itemBuilder: (context, index) {
                    final emp = route.employees[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 16,
                            color: Color(0xFF3B82F6),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            emp.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          if (emp.workPhone != null)
                            Text(
                              emp.workPhone!,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}

class _AddOutletBottomSheet extends StatefulWidget {
  final int routeId;

  const _AddOutletBottomSheet({required this.routeId});

  @override
  State<_AddOutletBottomSheet> createState() => _AddOutletBottomSheetState();
}

class _AddOutletBottomSheetState extends State<_AddOutletBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tab 1: Assign Existing
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allOutlets = [];
  bool _searchingOutlets = false;

  // Tab 2: Create New
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchOutlets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _fetchOutlets({String? search}) async {
    setState(() => _searchingOutlets = true);
    try {
      final list = await context.read<RouteProvider>().fetchAllOutlets(
        search: search,
      );
      setState(() {
        _allOutlets = list;
      });
    } catch (_) {
      // Ignore
    } finally {
      setState(() => _searchingOutlets = false);
    }
  }

  Future<void> _assignExisting(int outletId) async {
    setState(() => _isSaving = true);
    try {
      final res = await context.read<RouteProvider>().addOutletToRoute(
        widget.routeId,
        outletId: outletId,
      );
      if (res != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Outlet assigned to route successfully!'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _createAndAssign() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final mobile = _mobileController.text.trim();
      final email = _emailController.text.trim();
      final street = _streetController.text.trim();
      final city = _cityController.text.trim();

      // This position becomes the outlet's permanent geofence centre, so a
      // stale cached fix here would break every future check-in at this outlet.
      final position = await LocationService.getCurrentPosition(
        requireFresh: true,
        timeLimit: const Duration(seconds: 15),
      );

      if (!mounted) return;

      final res = await context.read<RouteProvider>().addOutletToRoute(
        widget.routeId,
        name: name,
        mobile: mobile.isEmpty ? null : mobile,
        email: email.isEmpty ? null : email,
        street: street.isEmpty ? null : street,
        city: city.isEmpty ? null : city,
        partnerLatitude: position.latitude,
        partnerLongitude: position.longitude,
      );

      if (res != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Outlet created and assigned successfully!'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Add Outlet to Route',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primaryStrong,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primaryStrong,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(text: 'Assign Existing'),
              Tab(text: 'Create New'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 380,
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: ASSIGN EXISTING
                Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: ssInputDecoration(
                        'Search outlets...',
                        Icons.search,
                      ),
                      onChanged: (val) => _fetchOutlets(search: val),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _searchingOutlets
                          ? const Center(child: CircularProgressIndicator())
                          : _allOutlets.isEmpty
                          ? const Center(
                              child: Text(
                                'No existing outlets found.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _allOutlets.length,
                              itemBuilder: (context, index) {
                                final item = _allOutlets[index];
                                final int outletId = item['id'];
                                final String name = item['name'] ?? '';
                                final String? city = item['city'];
                                final String? mobile =
                                    item['mobile'] ?? item['phone'];

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    border: Border.all(
                                      color: AppColors.borderSoft,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    subtitle: Text(
                                      [
                                        mobile,
                                        city,
                                      ].where((x) => x != null).join(' • '),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    trailing: _isSaving
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : IconButton(
                                            icon: const Icon(
                                              Icons.add_circle,
                                              color: AppColors.primaryStrong,
                                            ),
                                            onPressed: () =>
                                                _assignExisting(outletId),
                                          ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),

                // TAB 2: CREATE NEW
                SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: ssInputDecoration(
                            'Outlet Name *',
                            Icons.store,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Outlet name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _mobileController,
                          decoration: ssInputDecoration(
                            'Mobile / Phone Number',
                            Icons.phone,
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _emailController,
                          decoration: ssInputDecoration(
                            'Email Address',
                            Icons.email,
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _streetController,
                          decoration: ssInputDecoration(
                            'Street Address',
                            Icons.location_on,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _cityController,
                          decoration: ssInputDecoration('City', Icons.map),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _createAndAssign,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryStrong,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Create & Assign',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
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
        ],
      ),
    );
  }
}
