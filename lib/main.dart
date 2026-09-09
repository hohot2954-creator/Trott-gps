import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  runApp(const TrottGpsApp());
}

class TrottGpsApp extends StatelessWidget {
  const TrottGpsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS Pro Micro-Mobilité',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(45.75, 4.85),
    zoom: 14.0,
  );

  // Catégories unifiées (Trottinette, Mobylette, Moto 50cc)
  String _selectedCategory = 'Trottinette';
  final List<String> _categories = ['Trottinette', 'Mobylette', 'Moto 50cc'];

  // Types de trajets et profils regroupés
  String _selectedRouteType = 'Rapide';
  final List<String> _routeTypes = ['Rapide', 'Simple', 'Long', 'Balade'];

  double _currentSpeed = 0.0;
  StreamSubscription<Position>? _positionStreamSubscription;
  late FlutterTts _flutterTts;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadControlsAndRadars();
    _checkLocationPermissionAndStart();
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage("fr-FR");
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  void _loadControlsAndRadars() {
    final List<LatLng> policeLocations = [
      const LatLng(45.755, 4.852),
      const LatLng(45.742, 4.840),
    ];

    final List<LatLng> radarLocations = [
      const LatLng(45.760, 4.865),
      const LatLng(45.735, 4.830),
    ];

    setState(() {
      for (int i = 0; i < policeLocations.length; i++) {
        _markers.add(
          Marker(
            markerId: MarkerId('police_zone_$i'),
            position: policeLocations[i],
            infoWindow: const InfoWindow(
              title: '🚨 Zone de Contrôle Police',
              snippet: 'Soyez vigilant',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        );
      }

      for (int i = 0; i < radarLocations.length; i++) {
        _markers.add(
          Marker(
            markerId: MarkerId('radar_zone_$i'),
            position: radarLocations[i],
            infoWindow: const InfoWindow(
              title: '📷 Radar Fixe',
              snippet: 'Attention à la vitesse',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          ),
        );
      }
    });
  }

  Future<void> _checkLocationPermissionAndStart() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2,
    );

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      setState(() {
        double speedKmh = (position.speed >= 0) ? position.speed * 3.6 : 0.0;
        _currentSpeed = speedKmh < 0.8 ? 0.0 : speedKmh;
      });
    });
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('GPS - Mode : $_selectedCategory'),
        backgroundColor: Colors.grey[900],
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.satellite,
            initialCameraPosition: _initialPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: _markers,
            onMapCreated: (GoogleMapController controller) {
              _controller = controller;
            },
          ),
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentSpeed.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyanAccent,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'KM/H',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.bolt, size: 14, color: Colors.amberAccent),
                      SizedBox(width: 4),
                      Text(
                        'Optimisé Micro-Mobilité',
                        style: TextStyle(fontSize: 10, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.grey[900],
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barre unique de sélection de catégorie (Trottinette / Mobylette / Moto 50cc)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _categories.map((cat) {
                bool isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: Colors.amber,
                    backgroundColor: Colors.grey[800],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (bool selected) {
                      setState(() {
                        _selectedCategory = cat;
                      });
                      _speak("Profil $cat activé");
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            // Barre unique des types de trajets
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _routeTypes.map((type) {
                bool isSelected = _selectedRouteType == type;
                return ChoiceChip(
                  label: Text(type),
                  selected: isSelected,
                  selectedColor: Colors.cyan,
                  backgroundColor: Colors.grey[800],
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (bool selected) {
                    setState(() {
                      _selectedRouteType = type;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
