import 'package:secondary_sales/core/access/access_resources.dart';

class CorporateInstitutionalSaleModule {
  CorporateInstitutionalSaleModule._();

  static const corporateCode = 'CS';
  static const institutionCode = 'IS';

  static const corporateModuleScreen = 'screen.module.corporate_sale';
  static const institutionModuleScreen = 'screen.module.institution_sale';
  static const corporateOrdersList = 'screen.corporate_sale.orders.list';
  static const institutionOrdersList = 'screen.institution_sale.orders.list';
  static const corporateOrdersCreate = 'action.corporate_sale.orders.create';
  static const institutionOrdersCreate = 'action.institution_sale.orders.create';

  static const corporateOrdersPath = '/api/v1/cs/sale-orders';
  static const corporateCreatePath = '/api/v1/cs/sale-orders/create';
  static const institutionOrdersPath = '/api/v1/is/sale-orders';
  static const institutionCreatePath = '/api/v1/is/sale-orders/create';
}

const corporateInstitutionalSaleCatalog = <AccessResource>[
  AccessResource(
    CorporateInstitutionalSaleModule.corporateModuleScreen,
    'screen',
    'corporate_sale',
    'App Modules › Corporate Sales (CS)',
    [CorporateInstitutionalSaleModule.corporateCode],
  ),
  AccessResource(
    CorporateInstitutionalSaleModule.corporateOrdersList,
    'screen',
    'corporate_sale',
    'Corporate Sales (CS) › Orders',
    [CorporateInstitutionalSaleModule.corporateCode],
  ),
  AccessResource(
    CorporateInstitutionalSaleModule.corporateOrdersCreate,
    'action',
    'corporate_sale',
    'Corporate Sales (CS) › Create Order',
    [CorporateInstitutionalSaleModule.corporateCode],
  ),
  AccessResource(
    CorporateInstitutionalSaleModule.institutionModuleScreen,
    'screen',
    'institution_sale',
    'App Modules › Institution Sales (IS)',
    [CorporateInstitutionalSaleModule.institutionCode],
  ),
  AccessResource(
    CorporateInstitutionalSaleModule.institutionOrdersList,
    'screen',
    'institution_sale',
    'Institution Sales (IS) › Orders',
    [CorporateInstitutionalSaleModule.institutionCode],
  ),
  AccessResource(
    CorporateInstitutionalSaleModule.institutionOrdersCreate,
    'action',
    'institution_sale',
    'Institution Sales (IS) › Create Order',
    [CorporateInstitutionalSaleModule.institutionCode],
  ),
];
