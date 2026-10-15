part of '../api_service.dart';

extension ExpenseApi on ApiService {
  Future<Map<String, dynamic>> getExpenseCategories([int? employeeId]) async {
    return _post('/api/v1/hr/expense/categories', {
      if (employeeId != null) 'employee_id': employeeId,
    });
  }

  Future<Map<String, dynamic>> getExpenseDrafts(int employeeId) async {
    return _post('/api/v1/hr/expense/drafts', {
      'employee_id': employeeId,
    });
  }

  Future<Map<String, dynamic>> getExpenseSheetList({
    required int employeeId,
    required String mode, // 'own' or 'pending'
    String? state, // optional
    String? startDate, // optional
    String? endDate, // optional
  }) async {
    return _post('/api/v1/hr/expense/sheet/list', {
      'employee_id': employeeId,
      'mode': mode,
      if (state != null) 'state': state,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
    });
  }

  Future<Map<String, dynamic>> getExpenseSheetDetails(int sheetId) async {
    return _post('/api/v1/hr/expense/sheet/details', {
      'sheet_id': sheetId,
    });
  }

  Future<Map<String, dynamic>> updateExpenseSheet({
    required int sheetId,
    String? title,
    String? description,
    required List<Map<String, dynamic>> expenses,
    String? attachment,
    String? attachmentName,
  }) async {
    return _post('/api/v1/hr/expense/sheet/update', {
      'sheet_id': sheetId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      'expenses': expenses,
      if (attachment != null) 'attachment': attachment,
      if (attachmentName != null) 'attachment_name': attachmentName,
    });
  }

  Future<Map<String, dynamic>> submitExpenseSheet({
    required int employeeId,
    String? title,
    String? description,
    required List<Map<String, dynamic>> expenses,
    String? attachment,
    String? attachmentName,
  }) async {
    return _post('/api/v1/hr/expense/sheet/create', {
      'employee_id': employeeId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      'expenses': expenses,
      if (attachment != null) 'attachment': attachment,
      if (attachmentName != null) 'attachment_name': attachmentName,
    });
  }

  Future<Map<String, dynamic>> approveExpenseSheet(int sheetId) async {
    return _post('/api/v1/hr/expense/approve', {
      'sheet_id': sheetId,
    });
  }

  Future<Map<String, dynamic>> refuseExpenseSheet({
    required int sheetId,
    required String reason,
  }) async {
    return _post('/api/v1/hr/expense/refuse', {
      'sheet_id': sheetId,
      'reason': reason,
    });
  }

  Future<Map<String, dynamic>> createExpense({
    required int employeeId,
    required int categoryId,
    String? title,
    double? amount,
    String? date,
    String? description,
    double? odometerDayStart,
    double? odometerDayEnd,
    double? totalKmRun,
    String? odometerStartImage,
    String? odometerEndImage,
  }) async {
    return _post('/api/v1/hr/expense/create', {
      'employee_id': employeeId,
      'category_id': categoryId,
      if (title != null) 'title': title,
      if (amount != null) 'amount': amount,
      if (date != null) 'date': date,
      if (description != null) 'description': description,
      if (odometerDayStart != null) 'odometer_day_start': odometerDayStart,
      if (odometerDayEnd != null) 'odometer_day_end': odometerDayEnd,
      if (totalKmRun != null) 'total_km_run': totalKmRun,
      if (odometerStartImage != null) 'odometer_start_image': odometerStartImage,
      if (odometerEndImage != null) 'odometer_end_image': odometerEndImage,
    });
  }

  Future<Map<String, dynamic>> updateExpense({
    required int expenseId,
    int? categoryId,
    String? title,
    double? amount,
    String? date,
    String? description,
    double? odometerDayStart,
    double? odometerDayEnd,
    double? totalKmRun,
    String? odometerStartImage,
    String? odometerEndImage,
  }) async {
    return _post('/api/v1/hr/expense/update', {
      'expense_id': expenseId,
      if (categoryId != null) 'category_id': categoryId,
      if (title != null) 'title': title,
      if (amount != null) 'amount': amount,
      if (date != null) 'date': date,
      if (description != null) 'description': description,
      if (odometerDayStart != null) 'odometer_day_start': odometerDayStart,
      if (odometerDayEnd != null) 'odometer_day_end': odometerDayEnd,
      if (totalKmRun != null) 'total_km_run': totalKmRun,
      if (odometerStartImage != null) 'odometer_start_image': odometerStartImage,
      if (odometerEndImage != null) 'odometer_end_image': odometerEndImage,
    });
  }

  Future<Map<String, dynamic>> getExpenseList({
    required int employeeId,
    String mode = 'own',
    bool? isPersonalVehicle,
    String? startDate,
    String? endDate,
  }) async {
    return _post('/api/v1/hr/expense/list', {
      'employee_id': employeeId,
      'mode': mode,
      if (isPersonalVehicle != null) 'is_personal_vehicle': isPersonalVehicle,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
    });
  }

  Future<Map<String, dynamic>> submitPersonalVehicleExpenseSheet({
    required int expenseId,
    String? title,
    String? description,
  }) async {
    return _post('/api/v1/hr/expense/personal-vehicle/submit-sheet', {
      'expense_id': expenseId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
    });
  }
}

