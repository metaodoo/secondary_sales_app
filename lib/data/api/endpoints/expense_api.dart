part of '../api_service.dart';

extension ExpenseApi on ApiService {
  Future<Map<String, dynamic>> getExpenseCategories() async {
    return _post('/api/v1/hr/expense/categories', {});
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
}
