import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(const CyberScooterGps());

class CyberScooterGps extends StatelessWidget {
  const CyberScooterGps({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0E15),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double currentSpeedKmH = 0.0;
  bool isSatellite = true;
  String selectedRouteType = 'fast';
  
  final LatLng startPos = const LatLng(48.8566, 2.3522);
  final LatLng endPos = const LatLng(48.8700, 2.3000);
  List<LatLng> routePoints = [];

  @override
  void initState() {
    super.initState();
    _initSpeedometer();
  }

  void _initSpeedometer() async {
    await Geolocator.requestPermission();
    Geolocator.getPositionStream().listen((Position pos) {
      setState(() {
        currentSpeedKmH = pos.speed * 3.6;
      });
    });
  }

  Future<void> fetchRoute(String routeType) async {
    setState(() => selectedRouteType = routeType);
    final url = Uri.parse('https://router.project-osrm.org/route/v1/biking/${startPos.longitude},${startPos.latitude};${endPos.longitude},${endPos.latitude}?overview=full&geometries=geojson');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List coords = data['routes'][0]['geometry']['coordinates'];
      setState(() {
        routePoints = coords.map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(initialCenter: startPos, initialZoom: 14.0),
            children: [
              TileLayer(
                urlTemplate: isSatellite
                    ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.cyberscooter.app',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: routePoints,
                    strokeWidth: 6.0,
                    color: const Color(0xFF00FFCC),
                  ),
                ],
              ),
            ],
          ),

          Positioned(
            top: 50,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF00FFCC), width: 1.5),
              ),
              child: Column(
                children: [
                  Text(
                    currentSpeedKmH.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: currentSpeedKmH > 25 ? Colors.redAccent : const Color(0xFF00FFCC),
                    ),
                  ),
                  const Text('KM/H', style: TextStyle(fontSize: 10, color: Colors.white70)),
                ],
              ),
            ),
          ),

          Positioned(
            top: 50,
            right: 20,
            child: FloatingActionButton.small(
              backgroundColor: Colors.black87,
              foregroundColor: const Color(0xFF00FFCC),
              onPressed: () => setState(() => isSatellite = !isSatellite),
              child: Icon(isSatellite ? Icons.map : Icons.satellite),
            ),
          ),

          Positioned(
            bottom: 30,
            left: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFF131520).withOpacity(0.95),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("CHOIX DE L'ITINÉRAIRE TROTTINETTE", 
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildRouteOption('fast', 'Raccourci', Icons.bolt),
                      _buildRouteOption('safe', '100% Pistes', Icons.security),
                      _buildRouteOption('smooth', 'Zéro Pavés', Icons.nature),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteOption(String id, String label, IconData icon) {
    bool isSelected = selectedRouteType == id;
    return GestureDetector(
      onTap: () => fetchRoute(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00FFCC) : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? const Color(0xFF00FFCC) : Colors.white24),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.black : Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
