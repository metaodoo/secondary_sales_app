import 'package:shared_preferences/shared_preferences.dart';

// Previous testing defaults are intentionally disabled. The mobile app now
// receives server URL and DB from the first-run connection setup screen.
//
// class _Config {
//   final String baseUrl;
//   final String dbName;
//   const _Config(this.baseUrl, this.dbName);
// }
//
// const _kLocal = _Config('http://127.0.0.1:8069', 'ss_test');
//
// const _kTest = _Config(
//   'http://demo.metamorphosis.com.bd:8080',
//   'secondary_sales',
// );

class AppConstants {
  static String _baseUrl = '';
  static String _dbName = '';
  static bool _hasSavedConnection = false;

  static String get baseUrl => _baseUrl;
  static String get dbName => _dbName;
  static bool get hasSavedConnection => _hasSavedConnection;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBaseUrl = prefs.getString(baseUrlKey);
    final savedDbName = prefs.getString(dbNameKey);
    _hasSavedConnection = savedBaseUrl != null && savedDbName != null;
    _baseUrl = savedBaseUrl ?? '';
    _dbName = savedDbName ?? '';
  }

  static Future<void> saveConnection({
    required String baseUrl,
    required String dbName,
  }) async {
    _baseUrl = normalizeBaseUrl(baseUrl);
    _dbName = dbName.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(baseUrlKey, _baseUrl);
    await prefs.setString(dbNameKey, _dbName);
    _hasSavedConnection = true;
  }

  static String normalizeBaseUrl(String value) {
    var url = value.trim();
    if (url.isEmpty) return url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  static const String appName = 'Secondary Sales';
  static const String appVersion = '1.0.0+1';
  static const String apiPrefix = '/api/v1';

  // API Endpoints
  static const String authLoginEndpoint = '$apiPrefix/auth/login';
  static const String authBootstrapSessionEndpoint =
      '$apiPrefix/auth/bootstrap-session';
  static const String authRefreshEndpoint = '$apiPrefix/auth/refresh';
  static const String authLogoutEndpoint = '$apiPrefix/auth/logout';
  static const String mobileDeviceRegisterEndpoint =
      '$apiPrefix/mobile/device/register';
  static const String mobileDeviceUnregisterEndpoint =
      '$apiPrefix/mobile/device/unregister';
  static const String contactsEndpoint = '$apiPrefix/contacts';
  static const String createContactEndpoint = '$apiPrefix/contacts/create';
  static const String saleOrdersEndpoint = '$apiPrefix/sale-orders';
  static const String createSaleOrderEndpoint = '$apiPrefix/sale-orders/create';
  static const String deliveriesEndpoint = '$apiPrefix/deliveries';
  static const String productsEndpoint = '$apiPrefix/products';
  static const String employeesEndpoint = '$apiPrefix/employees';
  static const String virtualLocationsEndpoint = '$apiPrefix/virtual-locations';
  static const String createVirtualLocationEndpoint =
      '$apiPrefix/virtual-locations/create';
  static const String virtualTransfersEndpoint = '$apiPrefix/virtual-transfers';
  static const String warehousesEndpoint = '$apiPrefix/warehouses';
  static const String routeVisitsEndpoint = '$apiPrefix/route-visits';
  static const String routesEndpoint = '$apiPrefix/routes';
  static const String returnsEndpoint = '$apiPrefix/returns';
  static const String scrapsEndpoint = '$apiPrefix/scraps';
  static const String accessPermissionsEndpoint = '$apiPrefix/access/permissions';
  static const String accessCatalogSyncEndpoint =
      '$apiPrefix/access/catalog/sync';
  static const String dashboardSummaryEndpoint = '$apiPrefix/dashboard/summary';
  // Storage Keys
  static const String accessTokenKey = 'mobile_access_token';
  static const String refreshTokenKey = 'mobile_refresh_token';
  static const String sessionIdKey = 'odoo_session_id';
  static const String baseUrlKey = 'odoo_base_url';
  static const String dbNameKey = 'odoo_db_name';
  static const String tokenTypeKey = 'mobile_token_type';
  static const String tokenExpiresAtKey = 'mobile_token_expires_at';
  static const String userRoleKey = 'user_role';
  static const String userDataKey = 'user_data';
  static const String accessControlKey = 'mobile_access_control';
}
