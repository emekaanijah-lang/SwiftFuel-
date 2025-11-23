
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

const String googleMapsApiKey = "AIzaSyDEiRvAvQCfScTzwbCTq9-dpLXQQQfDudA";

enum TrackingStatus { orderReceived, driverOnTheWay }

class TrackingScreen extends StatefulWidget {
  final LatLng deliveryLocation;

  const TrackingScreen({super.key, required this.deliveryLocation});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final Completer<GoogleMapController> _controller = Completer();

  // Simulated Driver Location (Start point) - e.g., a nearby depot in Lagos
  LatLng _driverLocation = const LatLng(6.55, 3.35);

  Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  String _etaText = "Calculating...";
  Timer? _simulationTimer;
  TrackingStatus _status = TrackingStatus.orderReceived;

  @override
  void initState() {
    super.initState();
    _processOrder();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  void _processOrder() async {
    // Show "Order Received" state for 3 seconds
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      setState(() {
        _status = TrackingStatus.driverOnTheWay;
        _setInitialMarkers();
        _getRoute();
      });
    }
  }

  void _setInitialMarkers() {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Driver'),
        ),
        Marker(
          markerId: const MarkerId('delivery'),
          position: widget.deliveryLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Delivery Location'),
        ),
      };
    });
  }

  Future<void> _getRoute() async {
    final String url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${_driverLocation.latitude},${_driverLocation.longitude}&destination=${widget.deliveryLocation.latitude},${widget.deliveryLocation.longitude}&mode=driving&departure_time=now&key=$googleMapsApiKey";

    try {
      var response = await http.get(Uri.parse(url));
      var json = jsonDecode(response.body);

      if (json['status'] == 'OK') {
        var route = json['routes'][0];
        var leg = route['legs'][0];
        var durationInTraffic = leg['duration_in_traffic']['text'];
        var distance = leg['distance']['text'];
        var points = route['overview_polyline']['points'];

        // Corrected usage: PolylinePoints().decodePolyline is instance access.
        // The error "static method ... can't be accessed through an instance" suggests it IS static.
        // BUT if I use `PolylinePoints().decodePolyline`, I am creating an instance.
        // So `PolylinePoints().decodePolyline` -> Instance access.
        // `PolylinePoints.decodePolyline` -> Static access.
        // Let's check if flutter_polyline_points 3.1.0+ uses static or instance.
        // Documentation says it's an instance method for 1.0.0, but recent 3.1.0 might have broken changes or I am misinterpreting the error.
        // Wait, if the error says "static method ... can't be accessed through an instance", 
        // it means I WAS accessing it through an instance (PolylinePoints().decodePolyline) and it IS static.
        // So I should access it statically: `PolylinePoints.decodePolyline`.
        
        // HOWEVER, if I get "The named parameter 'apiKey' is required" when instantiating `PolylinePoints()`,
        // it means I MUST provide an API key to create an instance. 
        // `PolylinePoints(apiKey: googleMapsApiKey)` ??
        // But if decodePolyline is static, I don't need an instance?
        
        // Let's try accessing it via instance first, assuming I need to provide key.
        // PolylinePoints polylinePoints = PolylinePoints(); // This failed with "apiKey required".
        
        // Let's try:
        // PolylinePoints polylinePoints = PolylinePoints(); // Error: missing argument apiKey.
        // PolylinePoints().decodePolyline(...) // Error: instance access to static member.
        
        // This implies `decodePolyline` is indeed static, AND `PolylinePoints` constructor forces apiKey?
        // That would be weird design if I just want to decode.
        
        // Let's try just `PolylinePoints().decodePolyline(points)` ... oh wait.
        // If it is static, I should not instantiate.
        // `List<PointLatLng> result = PolylinePoints.decodePolyline(points);`
        
        List<PointLatLng> result = PolylinePoints.decodePolyline(points); 
        // Wait, I am going to try instantiating with the key to see if it works as instance method.
        // Maybe the static error was because I tried `PolylinePoints.decodePolyline`?
        // No, the error log said: `lib/features/tracking/presentation/screens/tracking_screen.dart:97:53 • instance_access_to_static_member`
        // Line 97 was: `List<PointLatLng> result = PolylinePoints().decodePolyline(points);`
        // `PolylinePoints()` is an instance. `decodePolyline` is being accessed on it.
        // The error says "static method ... can't be accessed through an instance".
        // This confirms `decodePolyline` IS STATIC.
        
        // So correct code is `PolylinePoints.decodePolyline(points)`.
        
        
        List<LatLng> polylineCoordinates = result
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();

        setState(() {
          _etaText = "$durationInTraffic ($distance)";
          _polylines.add(Polyline(
            polylineId: const PolylineId("route"),
            points: polylineCoordinates,
            color: Colors.blue,
            width: 5,
          ));
        });

        _fitBounds(polylineCoordinates);
        _startSimulation(polylineCoordinates);
      } else {
        debugPrint("Directions API Error: ${json['status']}");
        setState(() => _etaText = "Route Error");
      }
    } catch (e) {
      debugPrint("Error fetching route: $e");
      setState(() => _etaText = "Network Error");
    }
  }

  void _fitBounds(List<LatLng> points) async {
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      ),
      50, // padding
    ));
  }

  void _startSimulation(List<LatLng> path) {
    int index = 0;
    const int speedFactor = 5;

    _simulationTimer =
        Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (index >= path.length) {
        timer.cancel();
        setState(() => _etaText = "Arrived!");
        return;
      }

      setState(() {
        _driverLocation = path[index];
        _markers.removeWhere((m) => m.markerId.value == 'driver');
        _markers.add(Marker(
          markerId: const MarkerId('driver'),
          position: _driverLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Driver'),
          rotation: 0,
        ));
      });

      index += speedFactor;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_status == TrackingStatus.orderReceived) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 100),
              const SizedBox(height: 24),
              Text(
                "Order Received!",
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                "We are assigning a driver to your request.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _driverLocation,
              zoom: 14,
            ),
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (controller) => _controller.complete(controller),
          ),

          // Back Button
          Positioned(
            top: 50,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Driver Info & ETA Card
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundImage: NetworkImage(
                            "https://i.pravatar.cc/150?img=11"), // Placeholder Driver Image
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Ibrahim Musa",
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Text(
                              "Driver on the way",
                              style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                            const Text(
                              "45,000L Tanker • LAG-123-XY",
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      // Call Button
                      CircleAvatar(
                        backgroundColor: Colors.green.withValues(alpha: 0.1),
                        child: IconButton(
                          icon: const Icon(Icons.phone, color: Colors.green),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.access_time_filled,
                            color: Colors.blue, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Estimated Arrival",
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12),
                            ),
                            Text(
                              _etaText,
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
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
}
