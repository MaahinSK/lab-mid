================================================================================
                    SMART GEO-TAGGED LANDMARKS
                 CSE 489: Mobile Application Development
                         Student ID: 22201384
================================================================================

1. PROJECT OVERVIEW
--------------------------------------------------------------------------------
Smart Geo-Tagged Landmarks is a Flutter-based Android application that 
interacts with a faculty-provided REST API to manage and visualize landmarks 
with geographic coordinates. The app supports viewing landmarks on a map and 
in a list, recording visits with GPS location tracking, filtering/sorting by 
activity-based scores, and robust offline functionality.

The application demonstrates proficiency in:
- RESTful API integration with Dio
- Local data persistence with SQLite (sqflite)
- State management using Provider pattern
- Interactive maps using OpenStreetMap (flutter_map)
- GPS location services with Geolocator
- Offline-first architecture with visit queuing and sync


2. FEATURES IMPLEMENTED
--------------------------------------------------------------------------------
✅ Landmarks Display
   - Fetches landmarks from API and displays in list view
   - Shows title, image, score, and visit count for each landmark
   - Supports sorting by score (ascending/descending)
   - Supports filtering by minimum score threshold

✅ Map View
   - Displays all landmarks as markers on OpenStreetMap
   - Map centered on Bangladesh by default
   - Marker colors reflect score (red → orange → blue → green)
   - Tap marker to view details and visit landmark
   - Auto-zoom to fit all markers on screen
   - "My Location" button to center on current GPS position

✅ Visit Feature
   - Gets current GPS location when visiting a landmark
   - Calculates distance between user and landmark
   - Sends visit request to API with user coordinates
   - Displays success/failure messages via SnackBar
   - Updates landmark score after successful visit

✅ Activity Screen (Visit History)
   - Displays chronological list of all visits
   - Shows landmark name, timestamp, and distance for each visit
   - Persists visit history locally

✅ Add Landmark
   - Form to create new landmarks with title, lat/lon, and image
   - Auto-fetch current GPS location for new entries
   - Image selection from gallery
   - Multipart form-data upload to API

✅ Soft Delete Handling
   - Delete landmarks (marks as inactive on server)
   - Deleted landmarks are hidden from lists and map
   - View and manage existing landmarks in dedicated tab

✅ Offline Support (MANDATORY)
   - Caches all landmark data locally using SQLite
   - Displays cached data when internet is unavailable
   - Queues visit requests when offline
   - Auto-syncs queued visits when internet connection is restored
   - Visual indicators for offline mode and pending syncs

✅ Error Handling
   - Graceful handling of API failures
   - User-friendly error messages via SnackBar and dialogs
   - Network connectivity detection with auto-retry


3. API USAGE
--------------------------------------------------------------------------------
Base URL: https://labs.anontech.info/cse489/exm3/api.php
API Key: 22201384 (Student ID)

Endpoints Used:
┌─────────────────────┬────────┬─────────────────────────────────────────┐
│ Action              │ Method │ Description                             │
├─────────────────────┼────────┼─────────────────────────────────────────┤
│ get_landmarks       │ GET    │ Fetches all active landmarks            │
│ visit_landmark      │ POST   │ Records a visit with user coordinates   │
│ create_landmark     │ POST   │ Creates new landmark (multipart form)   │
│ delete_landmark     │ POST   │ Soft deletes a landmark                 │
│ restore_landmark    │ POST   │ Restores a deleted landmark             │
└─────────────────────┴────────┴─────────────────────────────────────────┘

HTTP Client: Dio package with custom interceptors for error handling
Image Upload: MultipartFile with form-data encoding


4. OFFLINE STRATEGY
--------------------------------------------------------------------------------
The app implements a robust offline-first architecture:

📦 Local Caching (SQLite)
   - Landmarks table: Stores all fetched landmarks with is_active flag
   - Visits table: Records all visits with timestamp and distance
   - Pending Visits table: Queues visits made while offline

🔄 Sync Mechanism
   1. On app startup, loads cached data immediately
   2. Fetches fresh data from API if online
   3. Updates local cache with new data

⏳ Visit Queuing
   - When offline: Visit saved locally and added to pending queue
   - When online: Visit sent to API immediately
   - If API fails: Visit automatically queued for later retry

📡 Connectivity Monitoring
   - Uses connectivity_plus to detect network changes
   - Auto-triggers sync when internet becomes available
   - Visual badge shows count of pending syncs



6. CHALLENGES FACED
--------------------------------------------------------------------------------
🔴 Challenge 1: Image URL Handling
   - Issue: API returns relative paths (uploads/filename.jpg)
   - Solution: Added fullImageUrl getter in Landmark model to prepend 
     base URL when needed

🔴 Challenge 2: NaN/Infinity Values in API Response
   - Issue: Some landmarks had null or invalid numeric fields causing crashes
   - Solution: Implemented robust parsing with null checks and 
     isFinite/isNaN validation in Landmark.fromJson()

🔴 Challenge 3: SnackBar Not Showing After Async Operations
   - Issue: "Looking up a deactivated widget's ancestor" error when showing
     SnackBar after closing bottom sheet
   - Solution: Captured ScaffoldMessenger reference BEFORE closing the 
     bottom sheet, ensuring valid context for displaying messages

🔴 Challenge 4: Offline Visit Queuing and Sync
   - Issue: Ensuring visits made offline are properly queued and synced
   - Solution: Created PendingVisit model and table; connectivity listener
     triggers auto-sync when internet becomes available

🔴 Challenge 5: SQLite Primary Key Conflicts
   - Issue: Manually inserting id=0 caused UNIQUE constraint violations
   - Solution: Made id nullable and let SQLite AUTOINCREMENT handle IDs

🔴 Challenge 6: Landmarks Outside Bangladesh
   - Issue: API returned test landmarks in California cluttering the map
   

================================================================================
                           END OF DOCUMENT
================================================================================