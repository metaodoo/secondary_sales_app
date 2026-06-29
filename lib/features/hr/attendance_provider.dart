import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:secondary_sales/data/api/api_service.dart';
import 'package:secondary_sales/features/auth/auth_provider.dart';

class AttendanceProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService.instance;
  final AuthProvider _authProvider;

  bool _isLoadingStatus = false;
  bool _isLoadingHistory = false;
  bool _isActionLoading = false;
  
  bool _isCheckedIn = false;
  String? _activeCheckInTime;
  String? _activeCheckInAddress;

  List<Map<String, dynamic>> _historyLogs = [];
  String? _errorMessage;

  bool get isLoadingStatus => _isLoadingStatus;
  bool get isLoadingHistory => _isLoadingHistory;
  bool get isActionLoading => _isActionLoading;
  bool get isCheckedIn => _isCheckedIn;
  String? get activeCheckInTime => _activeCheckInTime;
  String? get activeCheckInAddress => _activeCheckInAddress;
  List<Map<String, dynamic>> get historyLogs => _historyLogs;
  String? get errorMessage => _errorMessage;

  AttendanceProvider(this._authProvider) {
    _apiService.updateAccessToken(_authProvider.accessToken);
    _apiService.updateSessionId(_authProvider.sessionId);
    _apiService.updateEmployeeId(_authProvider.employeeId);
    _loadStatus();
    _loadHistory();
  }

  int get _employeeId => _authProvider.user?.employeeId ?? 0;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _loadStatus() async {
    if (_employeeId == 0) return;
    _isLoadingStatus = true;
    notifyListeners();

    try {
      final response = await _apiService.getAttendanceStatus(_employeeId);
      if (response['success'] == true) {
        final data = response['data'];
        _isCheckedIn = data['is_checked_in'] ?? false;
        _activeCheckInTime = data['active_check_in'];
        _activeCheckInAddress = data['check_in_address'];
      }
    } catch (e) {
      debugPrint('Failed to load attendance status: $e');
    } finally {
      _isLoadingStatus = false;
      notifyListeners();
    }
  }

  Future<void> _loadHistory() async {
    if (_employeeId == 0) return;
    _isLoadingHistory = true;
    notifyListeners();

    try {
      final response = await _apiService.getAttendanceHistory(employeeId: _employeeId);
      if (response['success'] == true) {
        final List logs = response['data'] ?? [];
        _historyLogs = logs.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (e) {
      debugPrint('Failed to load attendance history: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      _errorMessage = 'Location services are disabled. Please enable GPS and try again.';
      notifyListeners();
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _errorMessage = 'Location permissions are denied.';
        notifyListeners();
        return null;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      _errorMessage = 'Location permissions are permanently denied. Please enable in settings.';
      notifyListeners();
      return null;
    } 

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint("GPS Timeout, falling back to last known position.");
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) return lastPos;
      
      _errorMessage = 'Could not fetch GPS location. Ensure location is enabled and try outside.';
      notifyListeners();
      return null;
    }
  }

  Future<bool> performAction(String action) async {
    if (_employeeId == 0) return false;
    _isActionLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Get GPS Location
      final position = await _getCurrentLocation();
      if (position == null) {
        _isActionLoading = false;
        notifyListeners();
        return false;
      }

      // 2. Call API
      final response = await _apiService.submitAttendanceAction(
        employeeId: _employeeId,
        action: action,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (response['success'] == true) {
        // Reload everything on success
        await _loadStatus();
        await _loadHistory();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Action failed.';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
  }
}
