import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

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
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  
  LatLng _currentCenter = const LatLng(45.75, 4.85);

  String _selectedCategory = 'Trottinette';
  final List<String> _categories = ['Trottinette', 'Mobylette', 'Moto 50cc'];

  String _selectedRouteMode = 'Rapide';
  final List<String> _routeModes = ['Rapide', 'Balade / Pistes', 'Sécurisé'];

  double _currentSpeed = 0.0;
  double _totalDistanceMeters = 0.0;
  Position? _lastPosition;
  
  Timer? _sessionTimer;
  int _secondsElapsed = 0;
  bool _isSessionActive = false;

  StreamSubscription<Position>? _positionStreamSubscription;
  late FlutterTts _flutterTts;
  final List<Marker> _markers = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadControlsAndRadars();
    _checkLocationPermissionAndStart();
  }

  Future<void> _initTts() async {
    try {
      _flutterTts = FlutterTts();
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
          if (!mounted) return;
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
        Marker(
          point: const LatLng(45.760, 4.865),
          width: 40,
          height: 40,
          child: const Icon(Icons.camera_alt, color: Colors.red, size: 30),
        ),
      );
    });
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    setState(() { _isSearching = true; });

    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1');
      final response = await http.get(url, headers: {'User-Agent': 'TrottGpsApp/1.0'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          LatLng target = LatLng(lat, lon);

          setState(() {
            _currentCenter = target;
            _markers.add(
              Marker(
                point: target,
                width: 40,
                height: 40,
                child: const Icon(Icons.location_pin, color: Colors.greenAccent, size: 40),
              ),
            );
          });
          _mapController.move(target, 15.0);
          _speak("Destination trouvée");
        } else {
          _showSnack("Lieu introuvable", Colors.red);
        }
      }
    } catch (_) {
      _showSnack("Erreur de recherche", Colors.red);
    } finally {
      if (mounted) setState(() { _isSearching = false; });
    }
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, duration: const Duration(seconds: 2)),
    );
  }

  void _addCommunityAlert(String type, LatLng position) {
    Color iconColor = Colors.blue;
    String title = '';
    
    switch (type) {
      case 'police':
        title = '👮 Police / Contrôle';
        iconColor = Colors.blueAccent;
        break;
      case 'municipal':
        title = '🚓 Police Municipale';
        iconColor = Colors.indigoAccent;
        break;
      case 'danger':
        title = '⚠️ Danger / Nid-de-poule';
        iconColor = Colors.orangeAccent;
        break;
      default:
        title = '📍 Signalement';
    }

    setState(() {
      _markers.add(
        Marker(
          point: position,
          width: 40,
          height: 40,
          child: Icon(Icons.warning, color: iconColor, size: 35),
        ),
      );
    });

    _speak("Alerte $title enregistrée");
    _showSnack("Signalement '$title' publié !", Colors.blueGrey);
  }

  void _showReportDialog() {
    if (_lastPosition == null) {
      _showSnack("Attente de la position GPS...", Colors.red);
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

          LatLng newLatLng = LatLng(position.latitude, position.longitude);
          _currentCenter = newLatLng;
          _mapController.move(newLatLng, 16.0);

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
    _searchController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('GPS - $_selectedCategory ($_selectedRouteMode)'),
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
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.trottgps',
              ),
              MarkerLayer(markers: _markers),
            ],
          ),
          Positioned(
            top: 75,
            left: 15,
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
          Positioned(
            top: 15,
            left: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.grey[900]?.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.white70),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Rechercher une destination...',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (val) => _searchLocation(val),
                    ),
                  ),
                  if (_isSearching)
                    const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.blueAccent),
                      onPressed: () => _searchLocation(_searchController.text),
                    ),
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _routeModes.map((mode) {
                bool isSelected = _selectedRouteMode == mode;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(mode, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    selectedColor: Colors.blueAccent,
                    backgroundColor: Colors.grey[800],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (bool selected) {
                      setState(() {
                        _selectedRouteMode = mode;
                      });
                      _speak("Mode $mode activé");
                    },
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 5),
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
                      _speak("Profil $cat");
                    },
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
