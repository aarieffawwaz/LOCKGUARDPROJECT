import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  LatLng lockguardpoint = LatLng(0.0, 0.0); // Default location
  LatLng receiverLocation = LatLng(0.0, 0.0); // receiverLocation coordinates
  LatLng currentLocation = LatLng(0.0, 0.0); // Device current location
  String locationInfo = "Waiting for location...";
  String lockStatus = "Unknown"; // Lock status from Firebase
  String lastUpdated = "Never";
  String distanceInfo = "Calculating..."; // Distance info between receiver and lockguard
  final MapController mapController = MapController();
  bool isMarkersVisible = true;
  bool isTracking = false; // State for tracking toggle
  int countdown = 0; // Countdown timer display
  List<Marker> markers = [];
  List<LatLng> polylinePoints = [];
  Timer? trackingTimer; // Timer for periodic fetching
  Timer? countdownTimer; // Timer for countdown updates
  List<Map<String, dynamic>> searchResults = []; // List to store search results

  final String firebaseUrl = "https://lockguardv2-default-rtdb.asia-southeast1.firebasedatabase.app/gps.json";

  @override
  void initState() {
    super.initState();
    _initializeMarkers();
    _getCurrentLocation();
  }

  void _initializeMarkers() {
    setState(() {
      markers = [];
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      loc.Location location = loc.Location();
      bool _serviceEnabled = await location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await location.requestService();
        if (!_serviceEnabled) return;
      }

      loc.PermissionStatus _permissionGranted = await location.hasPermission();
      if (_permissionGranted == loc.PermissionStatus.denied) {
        _permissionGranted = await location.requestPermission();
        if (_permissionGranted != loc.PermissionStatus.granted) return;
      }

      final locData = await location.getLocation();
      setState(() {
        currentLocation = LatLng(locData.latitude ?? 0.0, locData.longitude ?? 0.0);
        markers.add(
          Marker(
            point: currentLocation,
            width: 50,
            height: 50,
            child: const Icon(Icons.phone_android_outlined, color: Colors.green, size: 40),
          ),
        );
      });
    } catch (e) {
      print("Error getting current location: $e");
    }
  }

  Future<void> _fetchLocationFromFirebase() async {
    try {
      final response = await http.get(Uri.parse(firebaseUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latitude = double.tryParse(data['latitude'].toString()) ?? 0.0;
        final longitude = double.tryParse(data['longitude'].toString()) ?? 0.0;
        final status = data['lock']?.toString() ?? "Unknown"; // Fetch lock status as string

        setState(() {
          lockguardpoint = LatLng(latitude, longitude);
          locationInfo = "Latitude: $latitude, Longitude: $longitude";
          lockStatus = status; // Update lockStatus with fetched data
          lastUpdated = DateTime.now().toLocal().toString().split('.')[0];

          _updateMarkers();
          _updatePolyline();
          _calculateDistance();
          mapController.move(lockguardpoint, 15.0);
        });
      } else {
        print("Failed to fetch location: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching location from Firebase: $e");
      setState(() {
        locationInfo = "Error fetching location.";
        distanceInfo = "Error calculating distance.";
      });
    }
  }

  void _calculateDistance() {
    final distance = Distance().as(
      LengthUnit.Kilometer,
      receiverLocation,
      lockguardpoint,
    );
    setState(() {
      distanceInfo = "Distance: ${distance.toStringAsFixed(2)} km";
    });
  }

  void _updateMarkers() {
    setState(() {
      markers = [
        Marker(
          point: lockguardpoint,
          width: 50,
          height: 50,
          child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
        ),
        Marker(
          point: receiverLocation,
          width: 50,
          height: 50,
          child: const Icon(Icons.my_location, color: Colors.red, size: 40),
        ),
      ];
    });
  }

  void _updatePolyline() {
    setState(() {
      polylinePoints = [receiverLocation, lockguardpoint];
    });
  }

  void _toggleTracking() async {
    if (isTracking) {
      trackingTimer?.cancel();
      countdownTimer?.cancel();
      setState(() {
        isTracking = false;
        countdown = 0;
      });
      print("Tracking stopped.");
    } else {
      setState(() {
        isTracking = true;
        countdown = 15;
      });
      // Fetch data immediately when tracking starts
      await _fetchLocationFromFirebase();
      _getCurrentLocation();

      trackingTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
        await _fetchLocationFromFirebase();
        _getCurrentLocation();
        setState(() {
          countdown = 15; // Reset countdown after fetch
        });
      });
      countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (countdown > 0) {
          setState(() {
            countdown--;
          });
        }
      });
      print("Tracking started.");
    }
  }

  Future<void> _searchLocation() async {
    TextEditingController searchController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Search Location'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'Enter place name',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12.0)),
                      ),
                    ),
                    onChanged: (value) async {
                      if (value.isNotEmpty) {
                        try {
                          List<Location> locations = await locationFromAddress(value);
                          List<Map<String, dynamic>> results = [];
                          for (var location in locations) {
                            List<Placemark> place = await placemarkFromCoordinates(location.latitude, location.longitude);
                            if (place.isNotEmpty) {
                              results.add({
                                'location': location,
                                'placemark': place.first,
                              });
                            }
                          }
                          setState(() {
                            searchResults = results;
                          });
                        } catch (e) {
                          print("Error searching location: $e");
                        }
                      } else {
                        setState(() {
                          searchResults = [];
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  if (searchResults.isNotEmpty)
                    Container(
                      height: 100,
                      child: ListView.builder(
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final result = searchResults[index];
                          final location = result['location'] as Location;
                          final placemark = result['placemark'] as Placemark;
                          return ListTile(
                            title: Text('${placemark.name}, ${placemark.locality}, ${placemark.country}'),
                            onTap: () {
                              setState(() {
                                receiverLocation = LatLng(location.latitude, location.longitude);
                                _updateMarkers();
                                _updatePolyline();
                                mapController.move(receiverLocation, 15.0);
                                searchResults = [];
                              });
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],  // Light blue background
      appBar: AppBar(
  backgroundColor: Colors.blue[700],
  title: Text(
    "Live GPS Map",
    style: GoogleFonts.poppins(
      textStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
  centerTitle: true,
  elevation: 0,
  actions: [
    IconButton(
      icon: const Icon(Icons.search, color: Colors.white),
      onPressed: _searchLocation,
    ),
  ],
),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: FlutterMap(
                  mapController: mapController,
                  options: MapOptions(initialCenter: receiverLocation, initialZoom: 15.0),
                  children: [
                    TileLayer(
                      urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    if (isMarkersVisible) MarkerLayer(markers: markers),
                    if (polylinePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: polylinePoints,
                            strokeWidth: 4.0,
                            color: Colors.red,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Live GPS Data:",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(locationInfo),
                            Text("Lock Status: $lockStatus"),
                            Text("Last Updated: $lastUpdated"),
                            Text(distanceInfo),
                            const SizedBox(height: 8),
                            if (isTracking) Text("Next update in: $countdown seconds"),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    FloatingActionButton(
                      onPressed: _toggleTracking,
                      backgroundColor: Colors.blue[700],
                      child: Icon(
                        isTracking ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (receiverLocation.latitude == 0.0 && receiverLocation.longitude == 0.0)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.25,
              left: MediaQuery.of(context).size.width * 0.1,
              right: MediaQuery.of(context).size.width * 0.1,
              child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: const Text(
                'Enter a destination in the search bar',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    trackingTimer?.cancel();
    countdownTimer?.cancel();
    super.dispose();
  }
}