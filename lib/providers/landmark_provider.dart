import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
  double minScore = 0.0;  // Made public
  bool sortByScoreAscending = true;  // Made public
  bool _isOnline = true;

  List<Landmark> get landmarks => _filteredLandmarks;
  List<Visit> get visits => _visits;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOnline => _isOnline;

  List<Landmark> get _filteredLandmarks {
    // Don't filter out negative scores - show all landmarks
    var filtered = _landmarks.where((l) {
      // Only filter out deleted landmarks
      return !l.isDeleted;
    }).toList();

    // Apply score filter only if minScore > 0
    if (minScore > 0) {
      filtered = filtered.where((l) => l.score >= minScore).toList();
    }

    // Sort by score
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
    connectivity.onConnectivityChanged.listen((result) {
      _isOnline = result != ConnectivityResult.none;
      if (_isOnline) {
        syncPendingVisits();
        fetchLandmarks();
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
    final position = await _locationService.getCurrentLocation();
    if (position == null) {
      _error = 'Unable to get current location';
      notifyListeners();
      return;
    }

    final landmark = _landmarks.firstWhere((l) => l.id == landmarkId);
    final distance = _locationService.calculateDistance(
      position.latitude,
      position.longitude,
      landmark.lat,
      landmark.lon,
    );

    if (!_isOnline) {
      // Queue for later sync
      final pendingVisit = PendingVisit(
        landmarkId: landmarkId,
        userLat: position.latitude,
        userLon: position.longitude,
        timestamp: DateTime.now(),
      );
      await _dbService.savePendingVisit(pendingVisit);

      // Save visit locally
      final visit = Visit(
        landmarkId: landmarkId,
        landmarkName: landmark.title,
        visitTime: DateTime.now(),
        distance: distance,
        userLat: position.latitude,
        userLon: position.longitude,
      );
      await _dbService.saveVisit(visit);
      _visits.insert(0, visit);

      _error = 'Visit queued for sync (offline)';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.visitLandmark(
        landmarkId: landmarkId,
        userLat: position.latitude,
        userLon: position.longitude,
      );

      if (result['success']) {
        // Parse the response data
        final data = result['data'];
        String message = 'Visit successful!';

        // Try to extract distance from response if available
        if (data != null && data is Map) {
          if (data.containsKey('distance')) {
            message = 'Visit successful! Distance: ${data['distance'].toStringAsFixed(0)}m';
          } else if (data.containsKey('message')) {
            message = data['message'];
          }
        }

        // Save visit locally
        final visit = Visit(
          landmarkId: landmarkId,
          landmarkName: landmark.title,
          visitTime: DateTime.now(),
          distance: distance,
          userLat: position.latitude,
          userLon: position.longitude,
        );
        await _dbService.saveVisit(visit);
        _visits.insert(0, visit);

        // Refresh landmarks to get updated score
        await fetchLandmarks();
        _error = message; // Use error field to show success message
      } else {
        _error = result['message'] ?? 'Failed to visit landmark';
      }
    } catch (e) {
      _error = 'Error: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> syncPendingVisits() async {
    final pendingVisits = await _dbService.getPendingVisits();

    for (var pending in pendingVisits) {
      try {
        final result = await _apiService.visitLandmark(
          landmarkId: pending.landmarkId,
          userLat: pending.userLat,
          userLon: pending.userLon,
        );

        if (result['success']) {
          await _dbService.deletePendingVisit(pending.id);
        }
      } catch (e) {
        // Keep in queue if failed
      }
    }

    await fetchLandmarks();
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