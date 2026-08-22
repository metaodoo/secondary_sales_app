import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:secondary_sales/features/routes/route_provider.dart';
import 'package:secondary_sales/core/widgets/ss_ui.dart';
import 'package:secondary_sales/core/theme/app_theme.dart';
import 'package:secondary_sales/data/models/sales/order_line_entry.dart';
import 'package:secondary_sales/features/contacts/screens/edit_outlet_screen.dart';
import 'package:secondary_sales/features/sales/screens/order_creation_screen.dart';
import 'package:secondary_sales/features/sales/screens/product_selection_screen.dart';

class OutletsListScreen extends StatefulWidget {
  const OutletsListScreen({super.key, this.startSecondarySale = false});

  final bool startSecondarySale;

  @override
  State<OutletsListScreen> createState() => _OutletsListScreenState();
}

class _OutletsListScreenState extends State<OutletsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _outlets = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchOutlets();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchOutlets([String? search]) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = Provider.of<RouteProvider>(context, listen: false);
      // Fetch ALL outlets by passing assigned: null
      final outlets = await provider.fetchAllOutlets(
        search: search,
        assigned: null,
      );
      if (mounted) {
        setState(() {
          _outlets = outlets;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _fetchOutlets(value);
    });
  }

  void _openOutlet(Map<String, dynamic> outlet) {
    if (widget.startSecondarySale) {
      final outletId = outlet['id'];
      if (outletId is! int) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This outlet cannot be selected.')),
        );
        return;
      }

      final name = outlet['name'] as String? ?? 'Unnamed Outlet';
      final code = outlet['ss_code'] ?? outlet['code'];
      final rawCode = (code != null && code.toString().trim().isNotEmpty)
          ? code.toString().trim()
          : null;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductSelectionScreen(
            saleType: 'secondary',
            partnerId: outletId,
            customerName: name,
            customerCode: rawCode,
          ),
        ),
      );
      return;
    }

    _editOutlet(outlet);
  }

  Future<void> _editOutlet(Map<String, dynamic> outlet) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditOutletScreen(outlet: outlet)),
    );
    if (updated == true) {
      _fetchOutlets(_searchController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
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
        title: Text(
          widget.startSecondarySale ? 'Select Outlet' : 'Outlets',
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
            child: ProfileAvatar(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderMuted, height: 1),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _fetchOutlets(_searchController.text),
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screen,
              vertical: AppSpacing.screen,
            ),
            children: [
              TextField(
                controller: _searchController,
                decoration: ssInputDecoration(
                  'Search outlets...',
                  Icons.search,
                ),
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 16),
              if (_error != null) ErrorPanel(_error!),
              if (_isLoading && _outlets.isNotEmpty) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
              ],
              if (_isLoading && _outlets.isEmpty)
                const LoadingState()
              else if (_outlets.isEmpty)
                const EmptyPanel(message: 'No outlets found')
              else
                ..._outlets.map((outlet) {
                  final name = outlet['name'] as String? ?? 'Unnamed Outlet';
                  final rawCode = outlet['ss_code'] ?? outlet['code'];
                  final codeStr = (rawCode != null && rawCode.toString().trim().isNotEmpty)
                      ? rawCode.toString().trim()
                      : null;
                  final street =
                      outlet['street'] as String? ?? 'No address provided';
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openOutlet(outlet),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderSoft),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: AppColors.borderMuted,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.storefront,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (codeStr != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Code: $codeStr',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    street,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                widget.startSecondarySale
                                    ? Icons.shopping_cart_checkout
                                    : Icons.edit_outlined,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () => _openOutlet(outlet),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
