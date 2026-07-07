/// App-owned catalog of gateable screens and actions.
///
/// Keys are STABLE, human-readable identifiers owned by the app. Odoo grants
/// reference these strings, so **never rename or reuse a shipped key** —
/// deprecate instead. The app syncs [accessCatalog] to Odoo
/// (`POST /access/catalog/sync`) so admins have something to grant to groups.
///
/// Convention:
///   `screen.<module>.<name>`     a whole screen / tab
///   `action.<module>.<name>`     a single button / gated capability
///
/// See ACCESS_CONTROL_PLAN.md. This list is expected to grow as more screens
/// and buttons are wrapped; adding a key here is additive and safe.
library;

/// Screen (view) resource keys.
class AppScreen {
  AppScreen._();

  // Top-level modules (module selection screen cards).
  static const modulePrimary = 'screen.module.primary';
  static const moduleSecondary = 'screen.module.secondary';
  static const moduleAttendance = 'screen.module.attendance';
  static const moduleLeave = 'screen.module.leave';
  static const moduleExpense = 'screen.module.expense';
  static const moduleMyTeam = 'screen.module.my_team';

  // Shell tabs.
  static const dashboard = 'screen.dashboard';
  static const settings = 'screen.settings';

  // Contacts.
  static const dealers = 'screen.contacts.dealers';
  static const distributorDetail = 'screen.contacts.distributor_detail';
  static const createDistributor = 'screen.contacts.create_distributor';
  static const outletsList = 'screen.contacts.outlets_list';
  static const editOutlet = 'screen.contacts.edit_outlet';

  // Routes & visits.
  static const routesList = 'screen.routes.list';
  static const routeDetail = 'screen.routes.detail';
  static const createRoute = 'screen.routes.create';
  static const createOutlet = 'screen.routes.create_outlet';
  static const visitsList = 'screen.routes.visits_list';
  static const newJointVisit = 'screen.routes.new_joint_visit';

  // Primary sales.
  static const primarySalesList = 'screen.sales.primary_list';
  static const createPrimarySale = 'screen.sales.create_primary';
  static const orderDetail = 'screen.sales.order_detail';
  static const deliveriesList = 'screen.sales.deliveries_list';

  // Secondary sales.
  static const orderCreate = 'screen.sales.order_create';
  static const productSelection = 'screen.sales.product_selection';
  static const secondaryOrdersList = 'screen.sales.secondary_orders_list';
  static const validateDelivery = 'screen.sales.validate_delivery';

  // Van loading.
  static const vanOperationsList = 'screen.van_loading.list';
  static const vanLoadForm = 'screen.van_loading.form';
  static const vanLoadingLocationDetail = 'screen.van_loading.location_detail';

  // Virtual transfers.
  static const transfersList = 'screen.transfers.list';
  static const transferDetail = 'screen.transfers.detail';
  static const createTransfer = 'screen.transfers.create';
  static const createVirtualLocation = 'screen.transfers.create_location';

  // Returns & scraps.
  static const returnsList = 'screen.returns.list';
  static const createReturn = 'screen.returns.create';
  static const scrapsList = 'screen.scraps.list';
  static const createScrap = 'screen.scraps.create';

  // Employees.
  static const salesOfficerList = 'screen.employees.list';
  static const salesOfficerDetail = 'screen.employees.detail';
  static const createSalesOfficer = 'screen.employees.create';

  // HR.
  static const attendance = 'screen.hr.attendance';
  static const leaveDashboard = 'screen.hr.leave';
  static const expenseDashboard = 'screen.hr.expense';
}

/// Action (button / capability) resource keys.
class AppAction {
  AppAction._();

  // Returns / scraps field & visibility permissions (mirror the existing
  // res.mobile.user.group flags in MobileAuthPermissions).
  static const returnsViewAll = 'action.returns.view_all';
  static const returnsEditSoQty = 'action.returns.edit_so_qty';
  static const returnsEditQcQty = 'action.returns.edit_qc_qty';
  static const returnsEditEffectiveQty = 'action.returns.edit_effective_qty';

  // Attendance behavior flag.
  static const attendanceSkipGeo = 'action.hr.skip_attendance_geo';

  // Sales.
  static const orderCreate = 'action.sales.order_create';
  static const orderConfirm = 'action.sales.order_confirm';
  static const orderCancel = 'action.sales.order_cancel';
  static const deliveryValidate = 'action.sales.delivery_validate';

  // Transfers.
  static const transferCreate = 'action.transfers.create';
  static const transferValidate = 'action.transfers.validate';
  static const transferCancel = 'action.transfers.cancel';

  // Returns / scraps create.
  static const returnCreate = 'action.returns.create';
  static const scrapCreate = 'action.scraps.create';

  // Routes / contacts / employees.
  static const routeCreate = 'action.routes.create';
  static const routeAddOutlet = 'action.routes.add_outlet';
  static const distributorCreate = 'action.contacts.distributor_create';
  static const outletCreate = 'action.contacts.outlet_create';
  static const employeeCreate = 'action.employees.create';

  // Visits.
  static const visitCheckIn = 'action.visits.check_in';
  static const visitCheckOut = 'action.visits.check_out';

  // HR / Leaves / Expenses.
  static const leaveCreate = 'action.hr.leave_create';
  static const expenseCreate = 'action.hr.expense_create';
}

/// One entry per resource key, shipped to Odoo so admins can grant it.
class AccessResource {
  const AccessResource(this.key, this.type, this.module, this.label);

  final String key; // AppScreen.* / AppAction.*
  final String type; // 'screen' | 'action'
  final String module; // 'sales', 'returns', 'hr', ...
  final String label; // human label for the Odoo admin UI

  Map<String, dynamic> toMap() => {
    'key': key,
    'type': type,
    'module': module,
    'label': label,
  };
}

/// The full catalog pushed to the backend. Keep labels admin-friendly.
const List<AccessResource> accessCatalog = [
  // Modules
  AccessResource(AppScreen.modulePrimary, 'screen', 'module', 'Primary Module'),
  AccessResource(
    AppScreen.moduleSecondary,
    'screen',
    'module',
    'Secondary Module',
  ),
  AccessResource(
    AppScreen.moduleAttendance,
    'screen',
    'module',
    'Attendance Module',
  ),
  AccessResource(AppScreen.moduleLeave, 'screen', 'module', 'Leave Module'),
  AccessResource(AppScreen.moduleExpense, 'screen', 'module', 'Expense Module'),
  AccessResource(AppScreen.moduleMyTeam, 'screen', 'module', 'My Team Module'),
  // Shell
  AccessResource(AppScreen.dashboard, 'screen', 'core', 'Dashboard'),
  AccessResource(AppScreen.settings, 'screen', 'core', 'Settings'),
  // Contacts
  AccessResource(AppScreen.dealers, 'screen', 'contacts', 'Dealers'),
  AccessResource(
    AppScreen.distributorDetail,
    'screen',
    'contacts',
    'Distributor Detail',
  ),
  AccessResource(
    AppScreen.createDistributor,
    'screen',
    'contacts',
    'Create Distributor',
  ),
  AccessResource(AppScreen.outletsList, 'screen', 'contacts', 'Outlets List'),
  AccessResource(AppScreen.editOutlet, 'screen', 'contacts', 'Edit Outlet'),
  // Routes
  AccessResource(AppScreen.routesList, 'screen', 'routes', 'Routes'),
  AccessResource(AppScreen.routeDetail, 'screen', 'routes', 'Route Detail'),
  AccessResource(AppScreen.createRoute, 'screen', 'routes', 'Create Route'),
  AccessResource(AppScreen.createOutlet, 'screen', 'routes', 'Create Outlet'),
  AccessResource(AppScreen.visitsList, 'screen', 'routes', 'Visits List'),
  AccessResource(
    AppScreen.newJointVisit,
    'screen',
    'routes',
    'New Joint Visit',
  ),
  // Primary sales
  AccessResource(
    AppScreen.primarySalesList,
    'screen',
    'sales',
    'Primary Sales',
  ),
  AccessResource(
    AppScreen.createPrimarySale,
    'screen',
    'sales',
    'Create Primary Sale',
  ),
  AccessResource(AppScreen.orderDetail, 'screen', 'sales', 'Order Detail'),
  AccessResource(AppScreen.deliveriesList, 'screen', 'sales', 'Deliveries'),
  // Secondary sales
  AccessResource(AppScreen.orderCreate, 'screen', 'sales', 'Create Order'),
  AccessResource(
    AppScreen.productSelection,
    'screen',
    'sales',
    'Product Selection',
  ),
  AccessResource(
    AppScreen.secondaryOrdersList,
    'screen',
    'sales',
    'Secondary Orders',
  ),
  AccessResource(
    AppScreen.validateDelivery,
    'screen',
    'sales',
    'Validate Delivery',
  ),
  // Van loading
  AccessResource(
    AppScreen.vanOperationsList,
    'screen',
    'van_loading',
    'Van Operations',
  ),
  AccessResource(
    AppScreen.vanLoadForm,
    'screen',
    'van_loading',
    'Van Load Form',
  ),
  AccessResource(
    AppScreen.vanLoadingLocationDetail,
    'screen',
    'van_loading',
    'Van Location Detail',
  ),
  // Transfers
  AccessResource(AppScreen.transfersList, 'screen', 'transfers', 'Transfers'),
  AccessResource(
    AppScreen.transferDetail,
    'screen',
    'transfers',
    'Transfer Detail',
  ),
  AccessResource(
    AppScreen.createTransfer,
    'screen',
    'transfers',
    'Create Transfer',
  ),
  AccessResource(
    AppScreen.createVirtualLocation,
    'screen',
    'transfers',
    'Create Virtual Location',
  ),
  // Returns & scraps
  AccessResource(AppScreen.returnsList, 'screen', 'returns', 'Returns'),
  AccessResource(AppScreen.createReturn, 'screen', 'returns', 'Create Return'),
  AccessResource(AppScreen.scrapsList, 'screen', 'scraps', 'Scraps'),
  AccessResource(AppScreen.createScrap, 'screen', 'scraps', 'Create Scrap'),
  // Employees
  AccessResource(
    AppScreen.salesOfficerList,
    'screen',
    'employees',
    'Sales Officers',
  ),
  AccessResource(
    AppScreen.salesOfficerDetail,
    'screen',
    'employees',
    'Sales Officer Detail',
  ),
  AccessResource(
    AppScreen.createSalesOfficer,
    'screen',
    'employees',
    'Create Sales Officer',
  ),
  // HR
  AccessResource(AppScreen.attendance, 'screen', 'hr', 'Attendance'),
  AccessResource(AppScreen.leaveDashboard, 'screen', 'hr', 'Leave'),
  AccessResource(AppScreen.expenseDashboard, 'screen', 'hr', 'Expense'),

  // Actions
  AccessResource(
    AppAction.returnsViewAll,
    'action',
    'returns',
    'View All Returns',
  ),
  AccessResource(
    AppAction.returnsEditSoQty,
    'action',
    'returns',
    'Edit SO Qty',
  ),
  AccessResource(
    AppAction.returnsEditQcQty,
    'action',
    'returns',
    'Edit QC Qty',
  ),
  AccessResource(
    AppAction.returnsEditEffectiveQty,
    'action',
    'returns',
    'Edit Effective Qty',
  ),
  AccessResource(
    AppAction.attendanceSkipGeo,
    'action',
    'hr',
    'Skip Attendance Geo-fence',
  ),
  AccessResource(AppAction.orderCreate, 'action', 'sales', 'Create Order'),
  AccessResource(AppAction.orderConfirm, 'action', 'sales', 'Confirm Order'),
  AccessResource(AppAction.orderCancel, 'action', 'sales', 'Cancel Order'),
  AccessResource(
    AppAction.deliveryValidate,
    'action',
    'sales',
    'Validate Delivery',
  ),
  AccessResource(
    AppAction.transferCreate,
    'action',
    'transfers',
    'Create Transfer',
  ),
  AccessResource(
    AppAction.transferValidate,
    'action',
    'transfers',
    'Validate Transfer',
  ),
  AccessResource(
    AppAction.transferCancel,
    'action',
    'transfers',
    'Cancel Transfer',
  ),
  AccessResource(AppAction.returnCreate, 'action', 'returns', 'Create Return'),
  AccessResource(AppAction.scrapCreate, 'action', 'scraps', 'Create Scrap'),
  AccessResource(AppAction.routeCreate, 'action', 'routes', 'Create Route'),
  AccessResource(
    AppAction.routeAddOutlet,
    'action',
    'routes',
    'Add Outlet to Route',
  ),
  AccessResource(
    AppAction.distributorCreate,
    'action',
    'contacts',
    'Create Distributor',
  ),
  AccessResource(AppAction.outletCreate, 'action', 'contacts', 'Create Outlet'),
  AccessResource(
    AppAction.employeeCreate,
    'action',
    'employees',
    'Create Sales Officer',
  ),
  AccessResource(AppAction.visitCheckIn, 'action', 'visits', 'Check In'),
  AccessResource(AppAction.visitCheckOut, 'action', 'visits', 'Check Out'),
  AccessResource(
    AppAction.leaveCreate,
    'action',
    'hr',
    'Create Leave Request',
  ),
  AccessResource(
    AppAction.expenseCreate,
    'action',
    'hr',
    'Create Expense Report',
  ),
];
