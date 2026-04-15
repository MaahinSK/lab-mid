import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/landmark_provider.dart';
import '../models/landmark.dart';
import '../utils/constants.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  bool _hasAdjustedView = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Landmarks Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _hasAdjustedView = false;
              });
              context.read<LandmarkProvider>().fetchLandmarks();
            },
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _goToCurrentLocation,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out_map),
            onPressed: () => _fitAllMarkers(context.read<LandmarkProvider>().landmarks),
          ),
        ],
      ),
      body: Consumer<LandmarkProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.landmarks.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!_hasAdjustedView && provider.landmarks.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fitAllMarkers(provider.landmarks);
              setState(() {
                _hasAdjustedView = true;
              });
            });
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(Constants.defaultLat, Constants.defaultLon),
                  initialZoom: Constants.defaultZoom,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.smart_landmarks',
                    maxZoom: 19,
                  ),
                  MarkerLayer(
                    markers: _buildMarkers(provider.landmarks),
                  ),
                ],
              ),

              if (!provider.isOnline)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Offline Mode - Showing cached data',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),

              if (provider.error != null)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: provider.error!.contains('✅') ||
                          provider.error!.contains('successful') ||
                          provider.error!.contains('offline')
                          ? Colors.green
                          : Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          provider.error!.contains('✅') ||
                              provider.error!.contains('successful')
                              ? Icons.check_circle
                              : Icons.error_outline,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            provider.error!,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 16),
                          onPressed: () => provider.clearError(),
                        ),
                      ],
                    ),
                  ),
                ),

              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${provider.landmarks.length} landmarks',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Marker> _buildMarkers(List<Landmark> landmarks) {
    final validLandmarks = landmarks.where((l) {
      if (l.lat.isNaN || l.lat.isInfinite || l.lon.isNaN || l.lon.isInfinite) {
        return false;
      }
      if (l.lat == 0.0 && l.lon == 0.0) return false;
      return true;
    }).toList();

    return validLandmarks.map((landmark) {
      return Marker(
        point: LatLng(landmark.lat, landmark.lon),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showLandmarkBottomSheet(context, landmark),
          child: Icon(
            Icons.location_pin,
            color: _getMarkerColor(landmark.score),
            size: 30,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  void _fitAllMarkers(List<Landmark> landmarks) {
    final validLandmarks = landmarks.where((l) {
      if (l.lat.isNaN || l.lat.isInfinite || l.lon.isNaN || l.lon.isInfinite) {
        return false;
      }
      if (l.lat == 0.0 && l.lon == 0.0) return false;
      return true;
    }).toList();

    if (validLandmarks.isEmpty) {
      _mapController.move(LatLng(Constants.defaultLat, Constants.defaultLon), 7.0);
      return;
    }

    double minLat = validLandmarks.first.lat;
    double maxLat = validLandmarks.first.lat;
    double minLon = validLandmarks.first.lon;
    double maxLon = validLandmarks.first.lon;

    for (var landmark in validLandmarks) {
      if (landmark.lat < minLat) minLat = landmark.lat;
      if (landmark.lat > maxLat) maxLat = landmark.lat;
      if (landmark.lon < minLon) minLon = landmark.lon;
      if (landmark.lon > maxLon) maxLon = landmark.lon;
    }

    if (minLat == maxLat && minLon == maxLon) {
      _mapController.move(LatLng(minLat, minLon), 12.0);
      return;
    }

    double latPadding = (maxLat - minLat) * 0.1;
    double lonPadding = (maxLon - minLon) * 0.1;

    if (latPadding.isNaN || latPadding.isInfinite) latPadding = 0.5;
    if (lonPadding.isNaN || lonPadding.isInfinite) lonPadding = 0.5;

    Future.delayed(const Duration(milliseconds: 100), () {
      try {
        final bounds = LatLngBounds(
          LatLng(minLat - latPadding, minLon - lonPadding),
          LatLng(maxLat + latPadding, maxLon + lonPadding),
        );

        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(50),
          ),
        );
      } catch (e) {
        _mapController.move(LatLng(Constants.defaultLat, Constants.defaultLon), 7.0);
      }
    });
  }

  Color _getMarkerColor(double score) {
    if (score.isNaN || score.isInfinite) return Colors.grey;
    if (score < 30) return Colors.red;
    if (score < 60) return Colors.orange;
    if (score < 80) return Colors.blue;
    return Colors.green;
  }

  Future<void> _goToCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        15.0,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to get current location')),
        );
      }
    }
  }

  void _showLandmarkBottomSheet(BuildContext context, Landmark landmark) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    landmark.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (landmark.fullImageUrl.isNotEmpty)
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[200],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: landmark.fullImageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Image not available', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[200],
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.landscape, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('No image available', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  _buildInfoRow(Icons.star, 'Score: ${landmark.score.toStringAsFixed(1)}', _getMarkerColor(landmark.score)),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.people, 'Total Visits: ${landmark.visitCount}', Colors.blue),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.straighten, 'Avg Distance: ${landmark.avgDistance.toStringAsFixed(0)}m', Colors.green),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.location_on, 'Lat: ${landmark.lat.toStringAsFixed(4)}, Lon: ${landmark.lon.toStringAsFixed(4)}', Colors.grey),

                  const SizedBox(height: 20),

                  // Visit button with notification
                  ElevatedButton.icon(
                    onPressed: () async {
                      print('=== MAP VISIT BUTTON PRESSED ===');
                      final String landmarkTitle = landmark.title;
                      final provider = context.read<LandmarkProvider>();

                      // Get the scaffold messenger BEFORE closing the bottom sheet
                      final scaffoldMessenger = ScaffoldMessenger.of(context);

                      // Show loading
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Text('Visiting $landmarkTitle...'),
                            ],
                          ),
                          backgroundColor: Colors.blue,
                          duration: const Duration(seconds: 10),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      print('Loading SnackBar shown');

                      // Close the bottom sheet
                      Navigator.pop(context);
                      print('Bottom sheet closed');

                      // Call visit
                      await provider.visitLandmark(landmark.id);
                      print('Visit completed. Provider error: ${provider.error}');

                      // Clear loading
                      scaffoldMessenger.clearSnackBars();
                      print('Loading SnackBar cleared');

                      // Show result
                      String message = provider.error ?? '✅ Visit completed!';
                      bool isSuccess = message.contains('✅') ||
                          message.contains('successful') ||
                          message.contains('📴') ||
                          message.contains('offline');

                      print('Showing result: $message (success: $isSuccess)');

                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: isSuccess ? Colors.green : Colors.red,
                          duration: const Duration(seconds: 5),
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                      print('Result SnackBar shown');
                    },

                    icon: const Icon(Icons.directions_walk),
                    label: const Text('Visit This Landmark'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}