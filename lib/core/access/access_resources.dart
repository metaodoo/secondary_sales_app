/// App-owned catalog of gateable screens and actions.
///
/// Keys are STABLE, human-readable identifiers owned by the app. Odoo grants
/// reference these strings, so **never rename or reuse a shipped key** —
/// deprecate instead. When a key is replaced, include the previous key in
/// [AccessResource.legacyKeys] so Odoo can carry existing hidden-resource
/// configuration across during catalog sync.
///
/// Convention:
///   `screen.<business_module>.<feature>.<name>`  a whole screen / tab
///   `action.<business_module>.<feature>.<name>`  a single capability
library;

/// Odoo mobile security module codes.
class SsModuleCode {
  SsModuleCode._();

  static const accounts = 'ACC';
  static const primarySales = 'PS';
  static const secondarySales = 'SS';
  static const hr = 'HR';
  static const dashboard = 'DSBRD';
}

/// Screen (view) resource keys.
class AppScreen {
  AppScreen._();

  // Top-level modules (module selection screen cards).
  static const modulePrimary = 'screen.module.primary_sale';
  static const moduleSecondary = 'screen.module.secondary_sale';
  static const moduleAttendance = 'screen.module.attendance';
  static const moduleLeave = 'screen.module.leave';
  static const moduleExpense = 'screen.module.accounts';
  static const moduleMyTeam = 'screen.module.dashboard';

  // Shell tabs.
  static const dashboard = 'screen.dashboard.home';
  static const settings = 'screen.dashboard.settings';

  // Primary sale contacts.
  static const dealers = 'screen.primary_sale.distributors.list';
  static const distributorDetail = 'screen.primary_sale.distributors.detail';
  static const createDistributor = 'screen.primary_sale.distributors.create';

  // Secondary sale contacts.
  static const outletsList = 'screen.secondary_sale.outlets.list';
  static const editOutlet = 'screen.secondary_sale.outlets.edit';

  // Secondary sale routes & visits.
  static const routesList = 'screen.secondary_sale.routes.list';
  static const routeDetail = 'screen.secondary_sale.routes.detail';
  static const createRoute = 'screen.secondary_sale.routes.create';
  static const createOutlet = 'screen.secondary_sale.routes.create_outlet';
  static const visitsList = 'screen.secondary_sale.visits.list';
  static const newJointVisit = 'screen.secondary_sale.visits.new_joint_visit';

  // Primary sales.
  static const primarySalesList = 'screen.primary_sale.orders.list';
  static const createPrimarySale = 'screen.primary_sale.orders.create';
  static const orderDetail = 'screen.primary_sale.orders.detail';
  static const deliveriesList = 'screen.primary_sale.deliveries.list';

  // Secondary sales.
  static const orderCreate = 'screen.secondary_sale.orders.create';
  static const productSelection = 'screen.secondary_sale.products.select';
  static const secondaryOrdersList = 'screen.secondary_sale.orders.list';
  static const secondaryDeliveriesList =
      'screen.secondary_sale.deliveries.list';
  static const validateDelivery = 'screen.secondary_sale.deliveries.validate';

  // Secondary sale van loading.
  static const vanOperationsList = 'screen.secondary_sale.van_loading.list';
  static const vanLoadForm = 'screen.secondary_sale.van_loading.form';
  static const vanLoadingLocationDetail =
      'screen.secondary_sale.van_loading.location_detail';

  // Secondary sale virtual transfers.
  static const transfersList = 'screen.secondary_sale.transfers.list';
  static const transferDetail = 'screen.secondary_sale.transfers.detail';
  static const createTransfer = 'screen.secondary_sale.transfers.create';
  static const createVirtualLocation =
      'screen.secondary_sale.transfers.create_location';

  // Primary/secondary return delivery.
  static const returnsList = 'screen.primary_sale.returns.list';
  static const createReturn = 'screen.primary_sale.returns.create';
  static const secondaryReturnsList = 'screen.secondary_sale.returns.list';
  static const secondaryCreateReturn = 'screen.secondary_sale.returns.create';

  // Primary/secondary return scrap.
  static const scrapsList = 'screen.primary_sale.scraps.list';
  static const createScrap = 'screen.primary_sale.scraps.create';
  static const secondaryScrapsList = 'screen.secondary_sale.scraps.list';
  static const secondaryCreateScrap = 'screen.secondary_sale.scraps.create';

  // Dashboard / team.
  static const salesOfficerList = 'screen.dashboard.sales_officers.list';
  static const salesOfficerDetail = 'screen.dashboard.sales_officers.detail';
  static const createSalesOfficer = 'screen.dashboard.sales_officers.create';

  // HR / Accounts.
  static const attendance = 'screen.hr.attendance';
  static const leaveDashboard = 'screen.hr.leave';
  static const expenseDashboard = 'screen.accounts.expense';

  static String deliveriesListFor(String moduleType) =>
      moduleType == 'secondary' ? secondaryDeliveriesList : deliveriesList;

  static String returnsListFor(String moduleType) =>
      moduleType == 'secondary' ? secondaryReturnsList : returnsList;

  static String createReturnFor(String moduleType) =>
      moduleType == 'secondary' ? secondaryCreateReturn : createReturn;

  static String scrapsListFor(String moduleType) =>
      moduleType == 'secondary' ? secondaryScrapsList : scrapsList;

  static String createScrapFor(String moduleType) =>
      moduleType == 'secondary' ? secondaryCreateScrap : createScrap;
}

/// Action (button / capability) resource keys.
class AppAction {
  AppAction._();

  // Return delivery field permissions. These mirror existing group flags and
  // intentionally remain shared until the backend exposes per-flow flags.
  static const returnsViewAll = 'action.return_delivery.view_all';
  static const returnsEditSoQty = 'action.return_delivery.edit_so_qty';
  static const returnsEditQcQty = 'action.return_delivery.edit_qc_qty';
  static const returnsEditEffectiveQty =
      'action.return_delivery.edit_effective_qty';

  // Attendance behavior flag.
  static const attendanceSkipGeo = 'action.hr.attendance.skip_geo_fence';

  // Primary sale orders and deliveries.
  static const primaryOrderCreate = 'action.primary_sale.orders.create';
  static const primaryOrderConfirm = 'action.primary_sale.orders.confirm';
  static const primaryOrderCancel = 'action.primary_sale.orders.cancel';
  static const primaryDeliveryValidate =
      'action.primary_sale.deliveries.validate';

  // Secondary sale orders and deliveries.
  static const orderCreate = 'action.secondary_sale.orders.create';
  static const orderConfirm = 'action.secondary_sale.orders.confirm';
  static const orderCancel = 'action.secondary_sale.orders.cancel';
  static const deliveryValidate = 'action.secondary_sale.deliveries.validate';

  // Secondary sale transfers.
  static const transferCreate = 'action.secondary_sale.transfers.create';
  static const transferValidate = 'action.secondary_sale.transfers.validate';
  static const transferCancel = 'action.secondary_sale.transfers.cancel';

  // Primary return delivery.
  static const returnCreate = 'action.primary_sale.returns.create';
  static const returnsSave = 'action.primary_sale.returns.save';
  static const returnsCancel = 'action.primary_sale.returns.cancel';
  static const returnsValidate = 'action.primary_sale.returns.validate';

  // Secondary return delivery.
  static const secondaryReturnCreate = 'action.secondary_sale.returns.create';
  static const secondaryReturnsSave = 'action.secondary_sale.returns.save';
  static const secondaryReturnsCancel = 'action.secondary_sale.returns.cancel';
  static const secondaryReturnsValidate =
      'action.secondary_sale.returns.validate';

  // Primary return scrap.
  static const scrapCreate = 'action.primary_sale.scraps.create';
  static const scrapsSave = 'action.primary_sale.scraps.save';
  static const scrapsCancel = 'action.primary_sale.scraps.cancel';
  static const scrapsValidate = 'action.primary_sale.scraps.validate';

  // Secondary return scrap.
  static const secondaryScrapCreate = 'action.secondary_sale.scraps.create';
  static const secondaryScrapsSave = 'action.secondary_sale.scraps.save';
  static const secondaryScrapsCancel = 'action.secondary_sale.scraps.cancel';
  static const secondaryScrapsValidate =
      'action.secondary_sale.scraps.validate';

  // Routes / contacts / employees.
  static const routeCreate = 'action.secondary_sale.routes.create';
  static const routeAddOutlet = 'action.secondary_sale.routes.add_outlet';
  static const distributorCreate = 'action.primary_sale.distributors.create';
  static const outletCreate = 'action.secondary_sale.outlets.create';
  static const employeeCreate = 'action.dashboard.sales_officers.create';

  // Visits.
  static const visitCheckIn = 'action.secondary_sale.visits.check_in';
  static const visitCheckOut = 'action.secondary_sale.visits.check_out';

  // HR / Leaves / Accounts.
  static const leaveCreate = 'action.hr.leave.create';
  static const expenseCreate = 'action.accounts.expense.create';

  static String orderCreateFor(String saleType) =>
      saleType == 'secondary' ? orderCreate : primaryOrderCreate;

  static String orderConfirmFor(String saleType) =>
      saleType == 'secondary' ? orderConfirm : primaryOrderConfirm;

  static String orderCancelFor(String saleType) =>
      saleType == 'secondary' ? orderCancel : primaryOrderCancel;

  static String deliveryValidateFor(String saleType) =>
      saleType == 'secondary' ? deliveryValidate : primaryDeliveryValidate;

  static String returnCreateFor(String moduleType) =>
      moduleType == 'secondary' ? secondaryReturnCreate : returnCreate;

  static String returnSaveFor(String moduleType) =>
      moduleType == 'secondary' ? secondaryReturnsSave : returnsSave;

  static String returnCancelFor(String moduleType) =>
      moduleType == 'secondary' ? secondaryReturnsCancel : returnsCancel;

  static String returnValidateFor(String moduleType) =>
      moduleType == 'secondary' ? secondaryReturnsValidate : returnsValidate;

  static String scrapCreateFor(String moduleType) =>
      moduleType == 'secondary' ? secondaryScrapCreate : scrapCreate;

  static String scrapSaveFor(String moduleType) =>
      moduleType == 'secondary' ? secondaryScrapsSave : scrapsSave;

  static String scrapCancelFor(String moduleType) =>
      moduleType == 'secondary' ? secondaryScrapsCancel : scrapsCancel;

  static String scrapValidateFor(String moduleType) =>
      moduleType == 'secondary' ? secondaryScrapsValidate : scrapsValidate;
}

/// One entry per resource key, shipped to Odoo so admins can grant it.
class AccessResource {
  const AccessResource(
    this.key,
    this.type,
    this.module,
    this.label,
    this.ssModuleCodes, {
    this.legacyKeys = const <String>[],
  });

  final String key; // AppScreen.* / AppAction.*
  final String type; // 'screen' | 'action'
  final String module; // app/business module, e.g. 'primary_sale'
  final String label; // human label for the Odoo admin UI
  final List<String> ssModuleCodes; // ss.module codes, e.g. ['PS', 'SS']
  final List<String>
  legacyKeys; // previous keys whose hidden grants should move

  Map<String, dynamic> toMap() => {
    'key': key,
    'type': type,
    'module': module,
    'label': label,
    'ss_module_codes': ssModuleCodes,
    if (legacyKeys.isNotEmpty) 'legacy_keys': legacyKeys,
  };
}

const _ps = <String>[SsModuleCode.primarySales];
const _ss = <String>[SsModuleCode.secondarySales];
const _hr = <String>[SsModuleCode.hr];
const _acc = <String>[SsModuleCode.accounts];
const _dashboard = <String>[SsModuleCode.dashboard];
const _psSs = <String>[SsModuleCode.primarySales, SsModuleCode.secondarySales];

/// The full catalog pushed to the backend. Keep labels admin-friendly.
const List<AccessResource> accessCatalog = [
  // Top-level modules.
  AccessResource(
    AppScreen.modulePrimary,
    'screen',
    'primary_sale',
    'Primary Sales Module',
    _ps,
    legacyKeys: ['screen.module.primary'],
  ),
  AccessResource(
    AppScreen.moduleSecondary,
    'screen',
    'secondary_sale',
    'Secondary Sales Module',
    _ss,
    legacyKeys: ['screen.module.secondary'],
  ),
  AccessResource(
    AppScreen.moduleAttendance,
    'screen',
    'hr',
    'Attendance Module',
    _hr,
  ),
  AccessResource(AppScreen.moduleLeave, 'screen', 'hr', 'Leave Module', _hr),
  AccessResource(
    AppScreen.moduleExpense,
    'screen',
    'accounts',
    'Accounts Module',
    _acc,
    legacyKeys: ['screen.module.expense'],
  ),
  AccessResource(
    AppScreen.moduleMyTeam,
    'screen',
    'dashboard',
    'Dashboard / My Team Module',
    _dashboard,
    legacyKeys: ['screen.module.my_team'],
  ),

  // Dashboard / core.
  AccessResource(
    AppScreen.dashboard,
    'screen',
    'dashboard',
    'Dashboard Home',
    _dashboard,
    legacyKeys: ['screen.dashboard'],
  ),
  AccessResource(
    AppScreen.settings,
    'screen',
    'dashboard',
    'Settings',
    _dashboard,
    legacyKeys: ['screen.settings'],
  ),

  // Primary sale contacts.
  AccessResource(
    AppScreen.dealers,
    'screen',
    'primary_sale',
    'Primary Sales - Distributor List',
    _ps,
    legacyKeys: ['screen.contacts.dealers'],
  ),
  AccessResource(
    AppScreen.distributorDetail,
    'screen',
    'primary_sale',
    'Primary Sales - Distributor Detail',
    _ps,
    legacyKeys: ['screen.contacts.distributor_detail'],
  ),
  AccessResource(
    AppScreen.createDistributor,
    'screen',
    'primary_sale',
    'Primary Sales - Create Distributor',
    _ps,
    legacyKeys: ['screen.contacts.create_distributor'],
  ),

  // Secondary sale contacts.
  AccessResource(
    AppScreen.outletsList,
    'screen',
    'secondary_sale',
    'Secondary Sales - Outlet List',
    _ss,
    legacyKeys: ['screen.contacts.outlets_list'],
  ),
  AccessResource(
    AppScreen.editOutlet,
    'screen',
    'secondary_sale',
    'Secondary Sales - Edit Outlet',
    _ss,
    legacyKeys: ['screen.contacts.edit_outlet'],
  ),

  // Secondary sale routes and visits.
  AccessResource(
    AppScreen.routesList,
    'screen',
    'secondary_sale',
    'Secondary Sales - Route List',
    _ss,
    legacyKeys: ['screen.routes.list'],
  ),
  AccessResource(
    AppScreen.routeDetail,
    'screen',
    'secondary_sale',
    'Secondary Sales - Route Detail',
    _ss,
    legacyKeys: ['screen.routes.detail'],
  ),
  AccessResource(
    AppScreen.createRoute,
    'screen',
    'secondary_sale',
    'Secondary Sales - Create Route',
    _ss,
    legacyKeys: ['screen.routes.create'],
  ),
  AccessResource(
    AppScreen.createOutlet,
    'screen',
    'secondary_sale',
    'Secondary Sales - Create Outlet From Route',
    _ss,
    legacyKeys: ['screen.routes.create_outlet'],
  ),
  AccessResource(
    AppScreen.visitsList,
    'screen',
    'secondary_sale',
    'Secondary Sales - Visit History',
    _ss,
    legacyKeys: ['screen.routes.visits_list'],
  ),
  AccessResource(
    AppScreen.newJointVisit,
    'screen',
    'secondary_sale',
    'Secondary Sales - New Joint Visit',
    _ss,
    legacyKeys: ['screen.routes.new_joint_visit'],
  ),

  // Primary sales.
  AccessResource(
    AppScreen.primarySalesList,
    'screen',
    'primary_sale',
    'Primary Sales - Order List',
    _ps,
    legacyKeys: ['screen.sales.primary_list'],
  ),
  AccessResource(
    AppScreen.createPrimarySale,
    'screen',
    'primary_sale',
    'Primary Sales - Create Order',
    _ps,
    legacyKeys: ['screen.sales.create_primary'],
  ),
  AccessResource(
    AppScreen.orderDetail,
    'screen',
    'primary_sale',
    'Primary Sales - Order Detail',
    _ps,
    legacyKeys: ['screen.sales.order_detail'],
  ),
  AccessResource(
    AppScreen.deliveriesList,
    'screen',
    'primary_sale',
    'Primary Sales - Delivery List',
    _ps,
    legacyKeys: ['screen.sales.deliveries_list'],
  ),

  // Secondary sales.
  AccessResource(
    AppScreen.orderCreate,
    'screen',
    'secondary_sale',
    'Secondary Sales - Create Order',
    _ss,
    legacyKeys: ['screen.sales.order_create'],
  ),
  AccessResource(
    AppScreen.productSelection,
    'screen',
    'secondary_sale',
    'Secondary Sales - Select Products',
    _ss,
    legacyKeys: ['screen.sales.product_selection'],
  ),
  AccessResource(
    AppScreen.secondaryOrdersList,
    'screen',
    'secondary_sale',
    'Secondary Sales - Order List',
    _ss,
    legacyKeys: ['screen.sales.secondary_orders_list'],
  ),
  AccessResource(
    AppScreen.secondaryDeliveriesList,
    'screen',
    'secondary_sale',
    'Secondary Sales - Delivery List',
    _ss,
    legacyKeys: ['screen.sales.deliveries_list'],
  ),
  AccessResource(
    AppScreen.validateDelivery,
    'screen',
    'secondary_sale',
    'Secondary Sales - Validate Delivery',
    _ss,
    legacyKeys: ['screen.sales.validate_delivery'],
  ),

  // Van loading.
  AccessResource(
    AppScreen.vanOperationsList,
    'screen',
    'secondary_sale',
    'Secondary Sales - Van Operations',
    _ss,
    legacyKeys: ['screen.van_loading.list'],
  ),
  AccessResource(
    AppScreen.vanLoadForm,
    'screen',
    'secondary_sale',
    'Secondary Sales - Van Load Form',
    _ss,
    legacyKeys: ['screen.van_loading.form'],
  ),
  AccessResource(
    AppScreen.vanLoadingLocationDetail,
    'screen',
    'secondary_sale',
    'Secondary Sales - Van Location Detail',
    _ss,
    legacyKeys: ['screen.van_loading.location_detail'],
  ),

  // Transfers.
  AccessResource(
    AppScreen.transfersList,
    'screen',
    'secondary_sale',
    'Secondary Sales - Virtual Transfer List',
    _ss,
    legacyKeys: ['screen.transfers.list'],
  ),
  AccessResource(
    AppScreen.transferDetail,
    'screen',
    'secondary_sale',
    'Secondary Sales - Virtual Transfer Detail',
    _ss,
    legacyKeys: ['screen.transfers.detail'],
  ),
  AccessResource(
    AppScreen.createTransfer,
    'screen',
    'secondary_sale',
    'Secondary Sales - Create Virtual Transfer',
    _ss,
    legacyKeys: ['screen.transfers.create'],
  ),
  AccessResource(
    AppScreen.createVirtualLocation,
    'screen',
    'secondary_sale',
    'Secondary Sales - Create Virtual Location',
    _ss,
    legacyKeys: ['screen.transfers.create_location'],
  ),

  // Return delivery.
  AccessResource(
    AppScreen.returnsList,
    'screen',
    'primary_sale',
    'Primary Sales - Return Delivery List',
    _ps,
    legacyKeys: ['screen.returns.list'],
  ),
  AccessResource(
    AppScreen.createReturn,
    'screen',
    'primary_sale',
    'Primary Sales - Create Return Delivery',
    _ps,
    legacyKeys: ['screen.returns.create'],
  ),
  AccessResource(
    AppScreen.secondaryReturnsList,
    'screen',
    'secondary_sale',
    'Secondary Sales - Return Delivery List',
    _ss,
    legacyKeys: ['screen.returns.list'],
  ),
  AccessResource(
    AppScreen.secondaryCreateReturn,
    'screen',
    'secondary_sale',
    'Secondary Sales - Create Return Delivery',
    _ss,
    legacyKeys: ['screen.returns.create'],
  ),

  // Return scrap.
  AccessResource(
    AppScreen.scrapsList,
    'screen',
    'primary_sale',
    'Primary Sales - Return Scrap List',
    _ps,
    legacyKeys: ['screen.scraps.list'],
  ),
  AccessResource(
    AppScreen.createScrap,
    'screen',
    'primary_sale',
    'Primary Sales - Create Return Scrap',
    _ps,
    legacyKeys: ['screen.scraps.create'],
  ),
  AccessResource(
    AppScreen.secondaryScrapsList,
    'screen',
    'secondary_sale',
    'Secondary Sales - Return Scrap List',
    _ss,
    legacyKeys: ['screen.scraps.list'],
  ),
  AccessResource(
    AppScreen.secondaryCreateScrap,
    'screen',
    'secondary_sale',
    'Secondary Sales - Create Return Scrap',
    _ss,
    legacyKeys: ['screen.scraps.create'],
  ),

  // Dashboard / team.
  AccessResource(
    AppScreen.salesOfficerList,
    'screen',
    'dashboard',
    'Dashboard - Sales Officer List',
    _dashboard,
    legacyKeys: ['screen.employees.list'],
  ),
  AccessResource(
    AppScreen.salesOfficerDetail,
    'screen',
    'dashboard',
    'Dashboard - Sales Officer Detail',
    _dashboard,
    legacyKeys: ['screen.employees.detail'],
  ),
  AccessResource(
    AppScreen.createSalesOfficer,
    'screen',
    'dashboard',
    'Dashboard - Create Sales Officer',
    _dashboard,
    legacyKeys: ['screen.employees.create'],
  ),

  // HR / Accounts.
  AccessResource(AppScreen.attendance, 'screen', 'hr', 'HR - Attendance', _hr),
  AccessResource(
    AppScreen.leaveDashboard,
    'screen',
    'hr',
    'HR - Leave Dashboard',
    _hr,
  ),
  AccessResource(
    AppScreen.expenseDashboard,
    'screen',
    'accounts',
    'Accounts - Expense Dashboard',
    _acc,
    legacyKeys: ['screen.hr.expense'],
  ),

  // Return delivery shared field permissions.
  AccessResource(
    AppAction.returnsViewAll,
    'action',
    'return_delivery',
    'Return Delivery - View All',
    _psSs,
    legacyKeys: ['action.returns.view_all'],
  ),
  AccessResource(
    AppAction.returnsEditSoQty,
    'action',
    'return_delivery',
    'Return Delivery - Edit SO Quantity',
    _psSs,
    legacyKeys: ['action.returns.edit_so_qty'],
  ),
  AccessResource(
    AppAction.returnsEditQcQty,
    'action',
    'return_delivery',
    'Return Delivery - Edit QC Quantity',
    _psSs,
    legacyKeys: ['action.returns.edit_qc_qty'],
  ),
  AccessResource(
    AppAction.returnsEditEffectiveQty,
    'action',
    'return_delivery',
    'Return Delivery - Edit Effective Quantity',
    _psSs,
    legacyKeys: ['action.returns.edit_effective_qty'],
  ),

  // HR behavior.
  AccessResource(
    AppAction.attendanceSkipGeo,
    'action',
    'hr',
    'HR - Skip Attendance Geo-fence',
    _hr,
    legacyKeys: ['action.hr.skip_attendance_geo'],
  ),

  // Primary sale actions.
  AccessResource(
    AppAction.primaryOrderCreate,
    'action',
    'primary_sale',
    'Primary Sales - Create Order',
    _ps,
    legacyKeys: ['action.sales.order_create'],
  ),
  AccessResource(
    AppAction.primaryOrderConfirm,
    'action',
    'primary_sale',
    'Primary Sales - Confirm Order',
    _ps,
    legacyKeys: ['action.sales.order_confirm'],
  ),
  AccessResource(
    AppAction.primaryOrderCancel,
    'action',
    'primary_sale',
    'Primary Sales - Cancel Order',
    _ps,
    legacyKeys: ['action.sales.order_cancel'],
  ),
  AccessResource(
    AppAction.primaryDeliveryValidate,
    'action',
    'primary_sale',
    'Primary Sales - Validate Delivery',
    _ps,
    legacyKeys: ['action.sales.delivery_validate'],
  ),

  // Secondary sale actions.
  AccessResource(
    AppAction.orderCreate,
    'action',
    'secondary_sale',
    'Secondary Sales - Create Order',
    _ss,
    legacyKeys: ['action.sales.order_create'],
  ),
  AccessResource(
    AppAction.orderConfirm,
    'action',
    'secondary_sale',
    'Secondary Sales - Confirm Order',
    _ss,
    legacyKeys: ['action.sales.order_confirm'],
  ),
  AccessResource(
    AppAction.orderCancel,
    'action',
    'secondary_sale',
    'Secondary Sales - Cancel Order',
    _ss,
    legacyKeys: ['action.sales.order_cancel'],
  ),
  AccessResource(
    AppAction.deliveryValidate,
    'action',
    'secondary_sale',
    'Secondary Sales - Validate Delivery',
    _ss,
    legacyKeys: ['action.sales.delivery_validate'],
  ),

  // Transfers.
  AccessResource(
    AppAction.transferCreate,
    'action',
    'secondary_sale',
    'Secondary Sales - Create Virtual Transfer',
    _ss,
    legacyKeys: ['action.transfers.create'],
  ),
  AccessResource(
    AppAction.transferValidate,
    'action',
    'secondary_sale',
    'Secondary Sales - Validate Virtual Transfer',
    _ss,
    legacyKeys: ['action.transfers.validate'],
  ),
  AccessResource(
    AppAction.transferCancel,
    'action',
    'secondary_sale',
    'Secondary Sales - Cancel Virtual Transfer',
    _ss,
    legacyKeys: ['action.transfers.cancel'],
  ),

  // Primary return delivery actions.
  AccessResource(
    AppAction.returnCreate,
    'action',
    'primary_sale',
    'Primary Sales - Create Return Delivery',
    _ps,
    legacyKeys: ['action.returns.create'],
  ),
  AccessResource(
    AppAction.returnsSave,
    'action',
    'primary_sale',
    'Primary Sales - Save Return Delivery',
    _ps,
    legacyKeys: ['action.returns.save'],
  ),
  AccessResource(
    AppAction.returnsCancel,
    'action',
    'primary_sale',
    'Primary Sales - Cancel Return Delivery',
    _ps,
    legacyKeys: ['action.returns.cancel'],
  ),
  AccessResource(
    AppAction.returnsValidate,
    'action',
    'primary_sale',
    'Primary Sales - Validate Return Delivery',
    _ps,
    legacyKeys: ['action.returns.validate'],
  ),

  // Secondary return delivery actions.
  AccessResource(
    AppAction.secondaryReturnCreate,
    'action',
    'secondary_sale',
    'Secondary Sales - Create Return Delivery',
    _ss,
    legacyKeys: ['action.returns.create'],
  ),
  AccessResource(
    AppAction.secondaryReturnsSave,
    'action',
    'secondary_sale',
    'Secondary Sales - Save Return Delivery',
    _ss,
    legacyKeys: ['action.returns.save'],
  ),
  AccessResource(
    AppAction.secondaryReturnsCancel,
    'action',
    'secondary_sale',
    'Secondary Sales - Cancel Return Delivery',
    _ss,
    legacyKeys: ['action.returns.cancel'],
  ),
  AccessResource(
    AppAction.secondaryReturnsValidate,
    'action',
    'secondary_sale',
    'Secondary Sales - Validate Return Delivery',
    _ss,
    legacyKeys: ['action.returns.validate'],
  ),

  // Primary return scrap actions.
  AccessResource(
    AppAction.scrapCreate,
    'action',
    'primary_sale',
    'Primary Sales - Create Return Scrap',
    _ps,
    legacyKeys: ['action.scraps.create'],
  ),
  AccessResource(
    AppAction.scrapsSave,
    'action',
    'primary_sale',
    'Primary Sales - Save Return Scrap',
    _ps,
    legacyKeys: ['action.scraps.save'],
  ),
  AccessResource(
    AppAction.scrapsCancel,
    'action',
    'primary_sale',
    'Primary Sales - Cancel Return Scrap',
    _ps,
    legacyKeys: ['action.scraps.cancel'],
  ),
  AccessResource(
    AppAction.scrapsValidate,
    'action',
    'primary_sale',
    'Primary Sales - Validate Return Scrap',
    _ps,
    legacyKeys: ['action.scraps.validate'],
  ),

  // Secondary return scrap actions.
  AccessResource(
    AppAction.secondaryScrapCreate,
    'action',
    'secondary_sale',
    'Secondary Sales - Create Return Scrap',
    _ss,
    legacyKeys: ['action.scraps.create'],
  ),
  AccessResource(
    AppAction.secondaryScrapsSave,
    'action',
    'secondary_sale',
    'Secondary Sales - Save Return Scrap',
    _ss,
    legacyKeys: ['action.scraps.save'],
  ),
  AccessResource(
    AppAction.secondaryScrapsCancel,
    'action',
    'secondary_sale',
    'Secondary Sales - Cancel Return Scrap',
    _ss,
    legacyKeys: ['action.scraps.cancel'],
  ),
  AccessResource(
    AppAction.secondaryScrapsValidate,
    'action',
    'secondary_sale',
    'Secondary Sales - Validate Return Scrap',
    _ss,
    legacyKeys: ['action.scraps.validate'],
  ),

  // Routes / contacts / employees.
  AccessResource(
    AppAction.routeCreate,
    'action',
    'secondary_sale',
    'Secondary Sales - Create Route',
    _ss,
    legacyKeys: ['action.routes.create'],
  ),
  AccessResource(
    AppAction.routeAddOutlet,
    'action',
    'secondary_sale',
    'Secondary Sales - Add Outlet to Route',
    _ss,
    legacyKeys: ['action.routes.add_outlet'],
  ),
  AccessResource(
    AppAction.distributorCreate,
    'action',
    'primary_sale',
    'Primary Sales - Create Distributor',
    _ps,
    legacyKeys: ['action.contacts.distributor_create'],
  ),
  AccessResource(
    AppAction.outletCreate,
    'action',
    'secondary_sale',
    'Secondary Sales - Create Outlet',
    _ss,
    legacyKeys: ['action.contacts.outlet_create'],
  ),
  AccessResource(
    AppAction.employeeCreate,
    'action',
    'dashboard',
    'Dashboard - Create Sales Officer',
    _dashboard,
    legacyKeys: ['action.employees.create'],
  ),
  AccessResource(
    AppAction.visitCheckIn,
    'action',
    'secondary_sale',
    'Secondary Sales - Visit Check In',
    _ss,
    legacyKeys: ['action.visits.check_in'],
  ),
  AccessResource(
    AppAction.visitCheckOut,
    'action',
    'secondary_sale',
    'Secondary Sales - Visit Check Out',
    _ss,
    legacyKeys: ['action.visits.check_out'],
  ),

  // HR / Accounts.
  AccessResource(
    AppAction.leaveCreate,
    'action',
    'hr',
    'HR - Create Leave Request',
    _hr,
    legacyKeys: ['action.hr.leave_create'],
  ),
  AccessResource(
    AppAction.expenseCreate,
    'action',
    'accounts',
    'Accounts - Create Expense Report',
    _acc,
    legacyKeys: ['action.hr.expense_create'],
  ),
];
