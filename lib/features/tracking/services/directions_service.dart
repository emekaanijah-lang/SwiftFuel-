import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class DirectionsService {
  // Replace with your actual key
  static const String _apiKey = "AIzaSyDEiRvAvQCfScTzwbCTq9-dpLXQQQfDudA";
  
  static const String _baseUrl = "https://maps.googleapis.com/maps/api/directions/json";

  Future<List<LatLng>> getRoute(LatLng origin, LatLng destination) async {
    final String url = 
        "$_baseUrl?origin=${origin.latitude},${origin.longitude}"
        "&destination=${destination.latitude},${destination.longitude}"
        "&key=$_apiKey";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if ((data['routes'] as List).isNotEmpty) {
        // Get the encoded polyline string from the first route
        String encodedPolyline = data['routes'][0]['overview_polyline']['points'];
        
        // Corrected usage: decodePolyline is a static method, so we access it via the class directly.
        List<PointLatLng> result = PolylinePoints.decodePolyline(encodedPolyline);
        
        // Convert to Google Maps LatLng format
        return result.map((point) => LatLng(point.latitude, point.longitude)).toList();
      }
    }
    return [];
  }
}
