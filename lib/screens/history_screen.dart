import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({Key? key}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String locationInfo = "Waiting for location...";
  String lockStatus = "Unknown";
  String lastUpdated = "Never";
  String distanceInfo = "Calculating...";
  int countdown = 0;

  LatLng? currentDeviceLocation;
  Timer? updateTimer;
  Timer? countdownTimer;
  bool isUpdating = false;
  List<Map<String, String>> historyData = [];

  Future<void> _fetchLiveTrackingData() async {
    final String firebaseUrl = "https://lockguardv2-default-rtdb.asia-southeast1.firebasedatabase.app/gps.json";
    try {
      final response = await http.get(Uri.parse(firebaseUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latitude = double.tryParse(data['latitude'].toString()) ?? 0.0;
        final longitude = double.tryParse(data['longitude'].toString()) ?? 0.0;
        final status = data['lock']?.toString() ?? "Unknown";

        if (currentDeviceLocation != null) {
          final distance = Distance().as(
            LengthUnit.Kilometer,
            currentDeviceLocation!,
            LatLng(latitude, longitude),
          );
          distanceInfo = "Distance: ${distance.toStringAsFixed(2)} km";
        } else {
          distanceInfo = "Current device location not available.";
        }

        setState(() {
          locationInfo = "Latitude: $latitude, Longitude: $longitude";
          lockStatus = status;
          lastUpdated = DateTime.now().toLocal().toString().split('.')[0];

          historyData.insert(0, {
            "location": locationInfo,
            "lockStatus": lockStatus,
            "lastUpdated": lastUpdated,
            "distance": distanceInfo,
          });
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

  Future<void> _getCurrentDeviceLocation() async {
    // Simulating getting device location
    setState(() {
      currentDeviceLocation = LatLng(-6.200305, 106.785771); // Example location
    });
  }

  void _toggleUpdating() async {
    if (isUpdating) {
      updateTimer?.cancel();
      countdownTimer?.cancel();
      setState(() {
        isUpdating = false;
        countdown = 0;
      });
      print("Auto update stopped.");
    } else {
      setState(() {
        isUpdating = true;
        countdown = 15;
      });
      // Fetch data immediately
      await _fetchLiveTrackingData();

      updateTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
        await _fetchLiveTrackingData();
        setState(() {
          countdown = 15;
        });
      });
      countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (countdown > 0) {
          setState(() {
            countdown--;
          });
        }
      });
      print("Auto update started.");
    }
  }

  @override
  void initState() {
    super.initState();
    _getCurrentDeviceLocation();
  }

  @override
  void dispose() {
    updateTimer?.cancel();
    countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],  // Light blue background
      appBar: AppBar(
  backgroundColor: Colors.blue[700],
  title: Text(
    "History",
    style: GoogleFonts.poppins(
      textStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),
  centerTitle: true,
  elevation: 0,
),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: historyData.length,
              itemBuilder: (context, index) {
                final entry = historyData[index];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  padding: const EdgeInsets.all(16.0),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry["location"] ?? "",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry["lockStatus"] ?? "",
                        style: const TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry["lastUpdated"] ?? "",
                        style: const TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry["distance"] ?? "",
                        style: const TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isUpdating ? "Next update in: $countdown seconds" : "Updates paused",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                FloatingActionButton(
                  onPressed: _toggleUpdating,
                  backgroundColor: Colors.blue[700],
                  child: Icon(
                    isUpdating ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}