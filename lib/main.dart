import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  runApp(const TrottGpsApp());
}

class TrottGpsApp extends StatelessWidget {
  const TrottGpsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trott GPS - Trajets',
      theme: ThemeData(primarySwatch: Colors.blue),
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
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(45.75, 4.85),
    zoom: 14.0,
  );

  // Mode de trajet sélectionné par défaut
  String _selectedRouteType = 'Rapide';

  final List<String> _routeTypes = ['Rapide', 'Simple', 'Long', 'Balade'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trott GPS - Satellite & Trajets'),
        backgroundColor: Colors.black87,
      ),
      body: Stack(
        children: [
          // 1. La carte satellite en fond
          const GoogleMap(
            mapType: MapType.satellite,
            initialCameraPosition: _initialPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),

          // 2. Le panneau d'options de trajets en haut
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.black87,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: _routeTypes.map((type) {
            bool isSelected = _selectedRouteType == type;
            return ChoiceChip(
              label: Text(type),
              selected: isSelected,
              selectedColor: Colors.blueAccent,
              backgroundColor: Colors.grey[800],
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold,
              ),
              onSelected: (bool selected) {
                setState(() {
                  _selectedRouteType = type;
                });
                // Action selon le mode choisi (ex: recalculer l'itinéraire trottinette)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Mode sélectionné : $type'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
