import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../models/landmark.dart';
import '../models/visit.dart';
import '../models/pending_visit.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';

class LandmarkProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final DatabaseService _dbService = DatabaseService();
  final LocationService _locationService = LocationService();

  List<Landmark> _landmarks = [];
  List<Visit> _visits = [];
  bool _isLoading = false;
  String? _error;
  double minScore = 0.0;
  bool sortByScoreAscending = true;
  bool _isOnline = true;

  List<Landmark> get landmarks => _filteredLandmarks;
  List<Visit> get visits => _visits;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOnline => _isOnline;

  List<Landmark> get _filteredLandmarks {
    var filtered = _landmarks.where((l) {
      return !l.isDeleted;
    }).toList();

    if (minScore > 0) {
      filtered = filtered.where((l) => l.score >= minScore).toList();
    }

    if (sortByScoreAscending) {
      filtered.sort((a, b) => a.score.compareTo(b.score));
    } else {
      filtered.sort((a, b) => b.score.compareTo(a.score));
    }

    return filtered;
  }

  LandmarkProvider() {
    _checkConnectivity();
    _loadCachedData();
    fetchLandmarks();
  }

  void _checkConnectivity() async {
    final connectivity = Connectivity();

    connectivity.onConnectivityChanged.listen((result) async {
      final wasOffline = !_isOnline;
      _isOnline = result != ConnectivityResult.none;

      if (wasOffline && _isOnline) {
        await syncPendingVisits();
      }

      notifyListeners();
    });

    final result = await connectivity.checkConnectivity();
    _isOnline = result != ConnectivityResult.none;
    notifyListeners();
  }

  Future<void> _loadCachedData() async {
    try {
      _landmarks = await _dbService.getCachedLandmarks();
      _visits = await _dbService.getVisits();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load cached data';
    }
  }

  Future<void> fetchLandmarks() async {
    if (!_isOnline) {
      await _loadCachedData();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final landmarks = await _apiService.getLandmarks();
      _landmarks = landmarks;
      await _dbService.saveLandmarks(landmarks);
    } catch (e) {
      _error = e.toString();
      await _loadCachedData();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> visitLandmark(int landmarkId) async {
    print('--- visitLandmark called for ID: $landmarkId ---');

    final landmarkIndex = _landmarks.indexWhere((l) => l.id == landmarkId);
    if (landmarkIndex == -1) {
      _error = 'Landmark not found';
      print('ERROR: $_error');
      notifyListeners();
      return;
    }

    final landmark = _landmarks[landmarkIndex];
    print('Found landmark: ${landmark.title}');

    Position? position;
    try {
      position = await _locationService.getCurrentLocation();
      print('Got location: ${position?.latitude}, ${position?.longitude}');
    } catch (e) {
      print('Location error: $e');
    }

    double userLat = position?.latitude ?? 0.0;
    double userLon = position?.longitude ?? 0.0;

    double distance = 0.0;
    if (position != null) {
      distance = _locationService.calculateDistance(
        userLat, userLon, landmark.lat, landmark.lon,
      );
      print('Calculated distance: $distance');
    }

    final visit = Visit(
      landmarkId: landmarkId,
      landmarkName: landmark.title,
      visitTime: DateTime.now(),
      distance: distance,
      userLat: userLat,
      userLon: userLon,
    );
    await _dbService.saveVisit(visit);
    _visits.insert(0, visit);
    notifyListeners();
    print('Visit saved locally');

    if (!_isOnline) {
      final pendingVisit = PendingVisit(
        landmarkId: landmarkId,
        userLat: userLat,
        userLon: userLon,
        timestamp: DateTime.now(),
      );
      await _dbService.savePendingVisit(pendingVisit);

      _error = '📴 Visit saved offline. Will sync when online.';
      print('OFFLINE: $_error');
      notifyListeners();
      return;
    }

    print('Online - sending to server...');

    try {
      final result = await _apiService.visitLandmark(
        landmarkId: landmarkId,
        userLat: userLat,
        userLon: userLon,
      );

      print('API response: $result');

      if (result['success']) {
        _error = '✅ Visit successful! Distance: ${distance.toStringAsFixed(0)}m';
        print('SUCCESS: $_error');
        notifyListeners();
        await fetchLandmarks();
      } else {
        final pendingVisit = PendingVisit(
          landmarkId: landmarkId,
          userLat: userLat,
          userLon: userLon,
          timestamp: DateTime.now(),
        );
        await _dbService.savePendingVisit(pendingVisit);
        _error = '⚠️ Visit queued for later sync.';
        print('SERVER ERROR: $_error');
        notifyListeners();
      }
    } catch (e) {
      final pendingVisit = PendingVisit(
        landmarkId: landmarkId,
        userLat: userLat,
        userLon: userLon,
        timestamp: DateTime.now(),
      );
      await _dbService.savePendingVisit(pendingVisit);
      _error = '📴 Network error. Visit queued.';
      print('EXCEPTION: $e');
      notifyListeners();
    }

    print('--- visitLandmark finished ---');
  }

  Future<void> syncPendingVisits() async {
    final pendingVisits = await _dbService.getPendingVisits();

    if (pendingVisits.isEmpty) return;

    print('Syncing ${pendingVisits.length} pending visits...');

    int successCount = 0;

    for (var pending in pendingVisits) {
      try {
        final result = await _apiService.visitLandmark(
          landmarkId: pending.landmarkId,
          userLat: pending.userLat,
          userLon: pending.userLon,
        );

        if (result['success']) {
          await _dbService.deletePendingVisit(pending.id);
          successCount++;
        }
      } catch (e) {
        print('Failed to sync visit ${pending.id}: $e');
      }
    }

    if (successCount > 0) {
      _error = '✅ Synced $successCount offline visits';
      await fetchLandmarks();
      notifyListeners();
    }
  }

  Future<int> getPendingVisitsCount() async {
    final pending = await _dbService.getPendingVisits();
    return pending.length;
  }

  void setMinScore(double score) {
    minScore = score;
    notifyListeners();
  }

  void toggleSortOrder() {
    sortByScoreAscending = !sortByScoreAscending;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}