import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../features/auth/presentation/providers/authentication_provider.dart';
import './order_summary_screen.dart'; // Import OrderSummaryScreen

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  static const CameraPosition _kDefaultLocation = CameraPosition(
    target: LatLng(6.5244, 3.3792), // Lagos
    zoom: 14.4746,
  );

  CameraPosition? _currentPosition;
  bool _loadingLocation = true;
  bool _isServiceAvailable = false;
  String? _currentLocationName;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    setState(() => _loadingLocation = true);

    // DEBUG: Force location to Lagos to test service area logic
    const double fakeLat = 6.5244;
    const double fakeLng = 3.3792;

    await Future.delayed(const Duration(milliseconds: 500));

    try {
      await _checkServiceAvailability(fakeLat, fakeLng);

      setState(() {
        _currentPosition = const CameraPosition(
          target: LatLng(fakeLat, fakeLng),
          zoom: 15,
        );
        _loadingLocation = false;
      });

      final GoogleMapController controller = await _controller.future;
      controller
          .animateCamera(CameraUpdate.newCameraPosition(_currentPosition!));
    } catch (e) {
      debugPrint("Error getting location: $e");
      setState(() => _loadingLocation = false);
    }
  }

  Future<void> _checkServiceAvailability(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final state = place.administrativeArea ?? '';
        final locality = place.locality ?? '';

        _currentLocationName = "$locality, $state";

        final normalizedState = state.toLowerCase();
        final isLagos = normalizedState.contains('lagos');
        final isRivers = normalizedState.contains('rivers');
        final isAbuja = normalizedState.contains('abuja') ||
            normalizedState.contains('federal capital territory') ||
            normalizedState.contains('fct');

        setState(() {
          _isServiceAvailable = isLagos || isRivers || isAbuja;
        });
      }
    } catch (e) {
      debugPrint("Geocoding error: $e");
      setState(() => _isServiceAvailable = true);
    }
  }

  void _showOrderPanel() {
    if (!_isServiceAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Sorry, SwiftFuel+ is currently only available in Lagos, Abuja, and Rivers State.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => OrderPanel(
          deliveryLocation: _currentPosition?.target ??
              _kDefaultLocation.target), // Pass location
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthenticationProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: theme.colorScheme.surface,
            child: Icon(Icons.person, color: theme.colorScheme.primary),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: theme.colorScheme.surface,
              child: IconButton(
                icon: Icon(Icons.logout, color: theme.colorScheme.error),
                onPressed: () => authProvider.signOut(),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _currentPosition ?? _kDefaultLocation,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
          ),
          if (_loadingLocation)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
          if (!_loadingLocation &&
              !_isServiceAvailable &&
              _currentLocationName != null)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Service unavailable in $_currentLocationName",
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: _isServiceAvailable ? _showOrderPanel : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isServiceAvailable
                    ? theme.colorScheme.secondary
                    : Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                elevation: 8,
                shadowColor: theme.colorScheme.secondary.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _isServiceAvailable ? 'ORDER NOW' : 'OUT OF SERVICE AREA',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'location_fab',
              backgroundColor: theme.colorScheme.surface,
              onPressed: _determinePosition,
              child: Icon(Icons.my_location, color: theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class OrderPanel extends StatelessWidget {
  final LatLng deliveryLocation;

  const OrderPanel({super.key, required this.deliveryLocation});

  void _showQuantityDialog(BuildContext context, String name, String unit,
      double pricePerUnit, double minQuantity, LatLng deliveryLocation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuantitySelectionSheet(
        productName: name,
        unit: unit,
        pricePerUnit: pricePerUnit,
        minQuantity: minQuantity,
        deliveryLocation: deliveryLocation, // Pass location
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Select Product',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          _ProductCard(
            name: 'Petrol (PMS)',
            icon: Icons.local_gas_station,
            price: '${currencyFormat.format(650)} / L',
            color: Colors.orange,
            onTap: () => _showQuantityDialog(
                context, 'Petrol (PMS)', 'Liters', 650, 10, deliveryLocation),
          ),
          const SizedBox(height: 16),
          _ProductCard(
            name: 'Diesel (AGO)',
            icon: Icons.directions_bus,
            price: '${currencyFormat.format(1100)} / L',
            color: Colors.blue,
            onTap: () => _showQuantityDialog(
                context, 'Diesel (AGO)', 'Liters', 1100, 25, deliveryLocation),
          ),
          const SizedBox(height: 16),
          _ProductCard(
            name: 'Cooking Gas (LPG)',
            icon: Icons.propane,
            price: '${currencyFormat.format(1200)} / kg',
            color: Colors.teal,
            onTap: () => _showQuantityDialog(
                context, 'Cooking Gas (LPG)', 'kg', 1200, 10, deliveryLocation),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class QuantitySelectionSheet extends StatefulWidget {
  final String productName;
  final String unit;
  final double pricePerUnit;
  final double minQuantity;
  final LatLng deliveryLocation; // Added

  const QuantitySelectionSheet({
    super.key,
    required this.productName,
    required this.unit,
    required this.pricePerUnit,
    required this.minQuantity,
    required this.deliveryLocation,
  });

  @override
  State<QuantitySelectionSheet> createState() => _QuantitySelectionSheetState();
}

class _QuantitySelectionSheetState extends State<QuantitySelectionSheet> {
  late double _quantity;
  final currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _quantity = widget.minQuantity;
  }

  void _increment() {
    setState(() => _quantity++);
  }

  void _decrement() {
    if (_quantity > widget.minQuantity) {
      setState(() => _quantity--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalCost = _quantity * widget.pricePerUnit;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.productName,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Minimum Order: ${widget.minQuantity} ${widget.unit}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _QuantityButton(icon: Icons.remove, onTap: _decrement),
              Text(
                '${_quantity.toStringAsFixed(0)} ${widget.unit}',
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              _QuantityButton(icon: Icons.add, onTap: _increment),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Cost', style: TextStyle(fontSize: 18)),
                Text(
                  currencyFormat.format(totalCost),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close QuantitySelectionSheet
                Navigator.pop(context); // Close OrderPanel
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => OrderSummaryScreen(
                              productName: widget.productName,
                              quantity: _quantity,
                              unit: widget.unit,
                              totalCost: totalCost,
                              deliveryLocation: widget.deliveryLocation,
                            )));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Review Order',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QuantityButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final String price;
  final Color color;
  final VoidCallback onTap;

  const _ProductCard({
    required this.name,
    required this.icon,
    required this.price,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Available',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                price,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
