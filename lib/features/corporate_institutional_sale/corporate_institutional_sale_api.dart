import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/data/models/sales/primary_order.dart';
import 'package:secondary_sales/features/corporate_institutional_sale/corporate_institutional_sale_catalog.dart';

class CorporateInstitutionalSaleApi {
  CorporateInstitutionalSaleApi({ApiService? api}) : _api = api ?? ApiService.instance;

  final ApiService _api;

  Future<List<PrimaryOrder>> fetchOrders({
    required bool corporate,
    int page = 1,
    int pageSize = 20,
  }) async {
    final result = await _api.executeRawPost(
      corporate
          ? CorporateInstitutionalSaleModule.corporateOrdersPath
          : CorporateInstitutionalSaleModule.institutionOrdersPath,
      {
        'page': page,
        'page_size': pageSize,
        'sale_type': 'all',
      },
    );
    if (result['success'] != true) {
      throw Exception(result['message'] ?? 'Failed to load orders');
    }
    final data = result['data'];
    if (data is! List) {
      return const [];
    }
    return data
        .whereType<Map>()
        .map((row) => PrimaryOrder.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<PrimaryOrder> createOrder({
    required bool corporate,
    required List<Map<String, dynamic>> orderLines,
    int? distributorId,
    int? outletId,
    String saleType = 'primary',
    bool confirm = false,
    String? clientOrderUuid,
  }) async {
    final params = <String, dynamic>{
      'sale_type': saleType,
      'order_lines': orderLines,
      'confirm': confirm,
    };
    if (distributorId != null) {
      params['distributor_id'] = distributorId;
    }
    if (outletId != null) {
      params['outlet_id'] = outletId;
    }
    if (clientOrderUuid != null && clientOrderUuid.isNotEmpty) {
      params['client_order_uuid'] = clientOrderUuid;
    }
    final result = await _api.executeRawPost(
      corporate
          ? CorporateInstitutionalSaleModule.corporateCreatePath
          : CorporateInstitutionalSaleModule.institutionCreatePath,
      params,
    );
    if (result['success'] != true || result['data'] is! Map) {
      throw Exception(result['message'] ?? 'Failed to create order');
    }
    return PrimaryOrder.fromMap(Map<String, dynamic>.from(result['data'] as Map));
  }
}
