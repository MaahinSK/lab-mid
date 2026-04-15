import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/landmark_provider.dart';
import '../widgets/landmark_card.dart';

class LandmarksScreen extends StatelessWidget {
  const LandmarksScreen({super.key});

  void _handleVisit(BuildContext context, LandmarkProvider provider, int landmarkId) async {
    print('=== _handleVisit STARTED for ID: $landmarkId ===');

    await provider.visitLandmark(landmarkId);

    print('=== _handleVisit COMPLETED ===');
    print('Provider error: ${provider.error}');

    // Show result
    String message = provider.error ?? 'Visit completed';
    bool isSuccess = !message.contains('error') && !message.contains('failed');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );

    provider.clearError();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Landmarks'),
        actions: [
          Consumer<LandmarkProvider>(
            builder: (context, provider, child) {
              return FutureBuilder<int>(
                future: provider.getPendingVisitsCount(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  if (count == 0) return const SizedBox.shrink();

                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.sync),
                        onPressed: () async {
                          if (provider.isOnline) {
                            await provider.syncPendingVisits();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(provider.error ?? 'Sync complete'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No internet connection'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                        tooltip: 'Sync pending visits ($count)',
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
        ],
      ),
      body: Consumer<LandmarkProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.landmarks.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.landmarks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    provider.error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.fetchLandmarks(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.landmarks.isEmpty) {
            return const Center(child: Text('No landmarks found'));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.filter_alt, size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              'Min Score: ${provider.minScore.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: Icon(
                          provider.sortByScoreAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          color: Colors.orange,
                        ),
                        onPressed: () => provider.toggleSortOrder(),
                        tooltip: provider.sortByScoreAscending
                            ? 'Sort: Low to High'
                            : 'Sort: High to Low',
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: provider.landmarks.length,
                  itemBuilder: (itemContext, index) {
                    final landmark = provider.landmarks[index];
                    return LandmarkCard(
                      landmark: landmark,
                      onVisit: () {
                        print('=== LANDMARK CARD CALLBACK EXECUTED ===');
                        print('Landmark ID: ${landmark.id}');
                        print('Landmark Title: ${landmark.title}');

                        // Directly show a SnackBar to test
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Visiting ${landmark.title}...'),
                            backgroundColor: Colors.blue,
                            duration: const Duration(seconds: 2),
                          ),
                        );

                        // Then call the async function
                        _handleVisit(context, provider, landmark.id);
                      },
                    );
                  },
                ),
              ),
              if (!provider.isOnline)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.orange,
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
            ],
          );
        },
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    final provider = context.read<LandmarkProvider>();
    double minScore = provider.minScore;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Filter by Score'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Show landmarks with score above:'),
              const SizedBox(height: 16),
              Text(
                '${minScore.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              Slider(
                value: minScore,
                min: 0,
                max: 100,
                divisions: 20,
                label: minScore.toStringAsFixed(0),
                onChanged: (value) {
                  setState(() {
                    minScore = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0', style: TextStyle(color: Colors.grey)),
                  Text('100', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                provider.setMinScore(0);
                Navigator.pop(context);
              },
              child: const Text('Reset'),
            ),
            ElevatedButton(
              onPressed: () {
                provider.setMinScore(minScore);
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}