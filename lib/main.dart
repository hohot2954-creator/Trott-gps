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

  String _selectedCategory = 'Trottinette';
  final List<String> _categories = ['Trottinette', 'Mobylette', 'Moto 50cc'];

  String _selectedRouteType = 'Rapide';
  final List<String> _routeTypes = ['Rapide', 'Simple', 'Long', 'Balade'];

  // Données de vitesse et de la séance en cours
  double _currentSpeed = 0.0;
  double _totalDistanceMeters = 0.0; // Distance totale en mètres
  Position? _lastPosition; // Pour calculer la distance entre 2 points GPS
  
  // Chrono de la session
  Timer? _sessionTimer;
  int _secondsElapsed = 0;
  bool _isSessionActive = false;

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

  // Démarrer ou arrêter la séance d'enregistrement
  void _toggleSession() {
    setState(() {
      _isSessionActive = !_isSessionActive;
      if (_isSessionActive) {
        _secondsElapsed = 0;
        _totalDistanceMeters = 0.0;
        _lastPosition = null;
        _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _secondsElapsed++;
          });
        });
        _speak("Séance enregistrée démarrée");
      } else {
        _sessionTimer?.cancel();
        _speak("Séance arrêtée. Bilan enregistré.");
      }
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
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

        // Si la séance est active, on calcule la distance parcourue automatiquement
        if (_isSessionActive && _lastPosition != null) {
          double distanceInMeters = Geolocator.distanceBetween(
            _lastPosition!.latitude,
            _lastPosition!.longitude,
            position.latitude,
            position.longitude,
          );
          // On filtre les petits sauts GPS aberrants (bruit)
          if (distanceInMeters > 1.0 && distanceInMeters < 100.0) {
            _totalDistanceMeters += distanceInMeters;
          }
        }
        _lastPosition = position;
      });
    });
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _sessionTimer?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('GPS - Mode : $_selectedCategory'),
        backgroundColor: Colors.grey[900],
        actions: [
          // Bouton direct pour lancer/arrêter l'enregistrement de séance
          IconButton(
            icon: Icon(
              _isSessionActive ? Icons.stop_circle : Icons.fiber_manual_record,
              color: _isSessionActive ? Colors.redAccent : Colors.greenAccent,
              size: 30,
            ),
            onPressed: _toggleSession,
            tooltip: _isSessionActive ? 'Arrêter l\'enregistrement' : 'Démarrer l\'enregistrement',
          ),
        ],
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
          
          // Compteur de vitesse + Tableau de bord de séance en direct
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isSessionActive ? Colors.redAccent : Colors.cyanAccent.withOpacity(0.5), 
                  width: 2,
                ),
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
                  // Affichage de la séance en direct si active
                  if (_isSessionActive) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.straighten, size: 14, color: Colors.amberAccent),
                        const SizedBox(width: 4),
                        Text(
                          '${(_totalDistanceMeters / 1000).toStringAsFixed(2)} km',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer, size: 14, color: Colors.greenAccent),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(_secondsElapsed),
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ] else ...[
                    const Text(
                      'Séance en pause',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
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
