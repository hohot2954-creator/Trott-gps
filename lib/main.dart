import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

  double _currentSpeed = 0.0;
  double _totalDistanceMeters = 0.0;
  Position? _lastPosition;
  
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
    try {
      await _flutterTts.setLanguage("fr-FR");
      await _flutterTts.setSpeechRate(0.5);
    } catch (_) {}
  }

  Future<void> _speak(String text) async {
    try {
      await _flutterTts.speak(text);
    } catch (_) {}
  }

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
        _speak("Séance arrêtée.");
      }
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _loadControlsAndRadars() {
    setState(() {
      _markers.add(
        const Marker(
          markerId: MarkerId('radar_1'),
          position: LatLng(45.760, 4.865),
          infoWindow: InfoWindow(title: '📷 Radar Fixe', snippet: 'Attention'),
        ),
      );
    });
  }

  void _addCommunityAlert(String type, LatLng position) {
    String markerIdVal = 'alert_${DateTime.now().millisecondsSinceEpoch}';
    String title = '';
    
    switch (type) {
      case 'police':
        title = '👮 Police / Contrôle';
        break;
      case 'municipal':
        title = '🚓 Police Municipale';
        break;
      case 'danger':
        title = '⚠️ Danger / Nid-de-poule';
        break;
      default:
        title = '📍 Signalement';
    }

    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId(markerIdVal),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            type == 'danger' ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(title: title, snippet: 'Ajouté par la communauté'),
        ),
      );
    });

    _speak("Alerte $title enregistrée");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Signalement '$title' publié !"),
        backgroundColor: Colors.blueGrey,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showReportDialog() {
    if (_lastPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Attente de la position GPS..."), backgroundColor: Colors.red),
      );
      return;
    }

    LatLng currentLatLng = LatLng(_lastPosition!.latitude, _lastPosition!.longitude);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🚨 Signaler un événement en direct',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amberAccent),
              ),
              const SizedBox(height: 15),
              ListTile(
                leading: const Icon(Icons.local_police, color: Colors.blueAccent, size: 30),
                title: const Text('Police / Contrôle de vitesse', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _addCommunityAlert('police', currentLatLng);
                },
              ),
              ListTile(
                leading: const Icon(Icons.security, color: Colors.indigoAccent, size: 30),
                title: const Text('Police Municipale', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _addCommunityAlert('municipal', currentLatLng);
                },
              ),
              ListTile(
                leading: const Icon(Icons.warning_amber, color: Colors.orangeAccent, size: 30),
                title: const Text('Danger / Route abîmée / Verglas', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _addCommunityAlert('danger', currentLatLng);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _checkLocationPermissionAndStart() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
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
        if (!mounted) return;
        setState(() {
          double speedKmh = (position.speed >= 0) ? position.speed * 3.6 : 0.0;
          _currentSpeed = speedKmh < 0.8 ? 0.0 : speedKmh;

          if (_isSessionActive && _lastPosition != null) {
            double distanceInMeters = Geolocator.distanceBetween(
              _lastPosition!.latitude,
              _lastPosition!.longitude,
              position.latitude,
              position.longitude,
            );
            if (distanceInMeters > 1.0 && distanceInMeters < 100.0) {
              _totalDistanceMeters += distanceInMeters;
            }
          }
          _lastPosition = position;
        });
      });
    } catch (_) {}
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
        title: Text('GPS - $_selectedCategory'),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: Icon(
              _isSessionActive ? Icons.stop_circle : Icons.fiber_manual_record,
              color: _isSessionActive ? Colors.redAccent : Colors.greenAccent,
              size: 30,
            ),
            onPressed: _toggleSession,
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
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
                border: Border.all(
                  color: _isSessionActive ? Colors.redAccent : Colors.cyanAccent.withOpacity(0.5), 
                  width: 2,
                ),
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
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  if (_isSessionActive) ...[
                    const Divider(color: Colors.white24, height: 12),
                    Text(
                      '${(_totalDistanceMeters / 1000).toStringAsFixed(2)} km',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                    ),
                    Text(
                      _formatTime(_secondsElapsed),
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showReportDialog,
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.campaign, color: Colors.white),
        label: const Text('Signaler', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      bottomNavigationBar: Container(
        color: Colors.grey[900],
        padding: const EdgeInsets.all(10),
        child: Row(
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
                  _speak("Profil $cat");
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
