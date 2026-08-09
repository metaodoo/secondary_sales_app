import 'package:flutter/material.dart';
import 'package:secondary_sales/data/models/sales/product.dart';
import 'package:secondary_sales/data/models/contacts/distribution_hub.dart';
import 'package:secondary_sales/data/models/sales/primary_order.dart';
import 'package:secondary_sales/data/models/sales/sale_order_detail.dart';
import 'package:secondary_sales/data/models/sales/delivery_prepare.dart';
import 'package:secondary_sales/data/models/inventory/warehouse.dart';
import 'package:secondary_sales/data/api/api_service.dart';

class PrimarySaleProvider with ChangeNotifier {
  final ApiService _apiService = ApiService.instance;
  ApiService get apiService => _apiService;

  List<DistributionHub> _hubs = [];
  List<Product> _products = [];
  int _totalProductCount = 0;
  List<PrimaryOrder> _recentOrders = [];
  DistributionHub? _selectedDistributor;
  SaleOrderDetail? _selectedOrder;
  DeliveryPrepare? _deliveryPrepare;
  List<Warehouse> _warehouses = [];
  List<StockLocation> _locations = [];
  int _loadingCount = 0;
  String? _error;

  List<DistributionHub> get hubs => _hubs;
  List<Product> get products => _products;
  int get totalProductCount => _totalProductCount;
  List<PrimaryOrder> get recentOrders => _recentOrders;
  DistributionHub? get selectedDistributor => _selectedDistributor;
  SaleOrderDetail? get selectedOrder => _selectedOrder;
  DeliveryPrepare? get deliveryPrepare => _deliveryPrepare;
  List<Warehouse> get warehouses => _warehouses;
  List<StockLocation> get locations => _locations;
  bool get isLoading => _loadingCount > 0;
  String? get error => _error;

  void updateAuth({String? accessToken, String? sessionId, int? employeeId}) {
    _apiService.updateAccessToken(accessToken);
    _apiService.updateSessionId(sessionId);
    _apiService.updateEmployeeId(employeeId);
  }

  void clearData({bool notify = true}) {
    _hubs = [];
    _products = [];
    _recentOrders = [];
    _selectedDistributor = null;
    _selectedOrder = null;
    _deliveryPrepare = null;
    _warehouses = [];
    _locations = [];
    _error = null;
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> fetchInitialData() async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      _hubs = await _apiService.getDistributionHubs();
      _products = await _apiService.getProducts();
      _warehouses = await _apiService.getWarehouses();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<void> fetchRecentOrders({
    String? search,
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    String saleType = 'primary',
    int? outletId,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      _recentOrders = await _apiService.getRecentOrders(
        search: search,
        status: status,
        dateFrom: dateFrom,
        dateTo: dateTo,
        saleType: saleType,
        outletId: outletId,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<void> searchHubs(String query) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      _hubs = await _apiService.getDistributionHubs(search: query);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<DistributionHub?> fetchDistributor(int id) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      _selectedDistributor = await _apiService.getDistributionHub(id);
      return _selectedDistributor;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<DistributionHub?> createDistributor({
    required String name,
    String? mobile,
    String? phone,
    String? email,
    String? street,
    String? street2,
    String? city,
    String? zip,
    String? vat,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      final distributor = await _apiService.createDistributionHub(
        name: name,
        mobile: mobile,
        phone: phone,
        email: email,
        street: street,
        street2: street2,
        city: city,
        zip: zip,
        vat: vat,
      );
      _hubs = [distributor, ..._hubs.where((hub) => hub.id != distributor.id)];
      _selectedDistributor = distributor;
      return distributor;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<DistributionHub?> updateDistributor(
    int id, {
    required String name,
    String? mobile,
    String? phone,
    String? email,
    String? street,
    String? street2,
    String? city,
    String? zip,
    String? vat,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      final distributor = await _apiService.updateDistributionHub(
        id,
        name: name,
        mobile: mobile,
        phone: phone,
        email: email,
        street: street,
        street2: street2,
        city: city,
        zip: zip,
        vat: vat,
      );
      _hubs = [distributor, ..._hubs.where((hub) => hub.id != distributor.id)];
      _selectedDistributor = distributor;
      return distributor;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<void> searchProducts(
    String query, {
    String? saleType,
    int? partnerId,
    bool? inStockOnly,
    String? sortBy,
  }) async {
    _error = null;
    notifyListeners();

    try {
      final res = await _apiService.getProductsWithCount(
        search: query,
        saleType: saleType,
        partnerId: partnerId,
        inStockOnly: inStockOnly,
        sortBy: sortBy,
      );
      _products = res.products;
      _totalProductCount = res.totalCount;
    } catch (e) {
      _error = e.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<SaleOrderDetail?> fetchOrderDetail(
    int orderId, {
    String saleType = 'primary',
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      _selectedOrder = await _apiService.getPrimarySaleOrderDetail(
        orderId,
        saleType: saleType,
      );
      return _selectedOrder;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<SaleOrderDetail?> cancelOrder(
    int orderId, {
    String saleType = 'primary',
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      _selectedOrder = await _apiService.cancelPrimarySaleOrder(
        orderId,
        saleType: saleType,
      );
      await fetchRecentOrders(saleType: saleType);
      return _selectedOrder;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<SaleOrderDetail?> confirmOrder(
    int orderId, {
    String saleType = 'primary',
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      _selectedOrder = await _apiService.confirmPrimarySaleOrder(
        orderId,
        saleType: saleType,
      );
      await fetchRecentOrders(saleType: saleType);
      return _selectedOrder;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> printOrder(
    int orderId, {
    String saleType = 'primary',
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      final data = await _apiService.printPrimarySaleOrder(
        orderId,
        saleType: saleType,
      );
      return data;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<DeliveryPrepare?> prepareDelivery(
    int orderId, {
    int? pickingId,
    String? saleType,
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      _deliveryPrepare = await _apiService.preparePrimarySaleDelivery(
        orderId,
        pickingId: pickingId,
        saleType: saleType,
      );
      _warehouses = _deliveryPrepare!.warehouses;
      return _deliveryPrepare;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<List<AvailableLot>> fetchAvailableLots({
    required int productId,
    required int saleOrderId,
    int? locationId,
    int? pickingId,
  }) async {
    _error = null;
    notifyListeners();

    try {
      return await _apiService.getDeliveryProductLots(
        productId,
        saleOrderId: saleOrderId,
        locationId: locationId,
        pickingId: pickingId,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<List<DeliveryLotInput>> autoAssignLots({
    required int productId,
    required double quantity,
    required int saleOrderId,
    int? pickingId,
    int? locationId,
  }) async {
    _error = null;
    notifyListeners();

    try {
      return await _apiService.autoAssignDeliveryLots(
        productId: productId,
        quantity: quantity,
        saleOrderId: saleOrderId,
        pickingId: pickingId,
        locationId: locationId,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<SaleOrderDetail?> validateDelivery({
    required int orderId,
    required int pickingId,
    int? warehouseId,
    int? locationId,
    required List<DeliveryLineInput> lines,
    bool createBackorder = true,
    String saleType = 'primary',
    String action = 'validate',
  }) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      _selectedOrder = await _apiService.validatePrimarySaleDelivery(
        orderId: orderId,
        pickingId: pickingId,
        warehouseId: warehouseId,
        locationId: locationId,
        lines: lines,
        createBackorder: createBackorder,
        saleType: saleType,
        action: action,
      );
      _deliveryPrepare = null;
      await fetchRecentOrders(saleType: saleType);
      return _selectedOrder;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<bool> submitOrder(
    int hubId,
    List<Map<String, dynamic>> items,
    DateTime expectedDeliveryDate, {
    int? warehouseId,
    bool confirm = true,
  }) async {
    _loadingCount++;
    notifyListeners();

    try {
      await _apiService.createPrimarySalesOrder(
        hubId: hubId,
        items: items,
        expectedDeliveryDate: expectedDeliveryDate,
        warehouseId: warehouseId,
        confirm: confirm,
      );
      await fetchRecentOrders();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<bool> editOrder(
    int orderId,
    int hubId,
    List<Map<String, dynamic>> items,
    DateTime expectedDeliveryDate, {
    int? warehouseId,
    bool confirm = true,
  }) async {
    _loadingCount++;
    notifyListeners();

    try {
      await _apiService.updateSalesOrder(
        orderId: orderId,
        hubId: hubId,
        items: items,
        expectedDeliveryDate: expectedDeliveryDate,
        confirm: confirm,
        warehouseId: warehouseId,
      );
      await fetchRecentOrders();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<bool> editSecondaryOrder({
    required int orderId,
    required int outletId,
    required List<Map<String, dynamic>> items,
    int? mediumId,
    int? routeId,
    int? visitId,
    bool confirm = true,
  }) async {
    _loadingCount++;
    notifyListeners();

    try {
      await _apiService.updateSecondarySaleOrder(
        orderId: orderId,
        outletId: outletId,
        items: items,
        mediumId: mediumId,
        routeId: routeId,
        visitId: visitId,
        confirm: confirm,
      );
      await fetchRecentOrders(saleType: 'secondary');
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }

  Future<void> fetchLocations({String? search}) async {
    _loadingCount++;
    _error = null;
    notifyListeners();

    try {
      _locations = await _apiService.getLocations(
        search: search,
        usage: 'internal',
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      if (_loadingCount > 0) _loadingCount--;
      notifyListeners();
    }
  }
}
