import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import '../../../../features/auth/presentation/providers/authentication_provider.dart';
import '../../../tracking/presentation/screens/tracking_screen.dart';

class OrderSummaryScreen extends StatefulWidget {
  final String productName;
  final double quantity;
  final String unit;
  final double totalCost;
  final LatLng deliveryLocation;

  const OrderSummaryScreen({
    super.key,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.totalCost,
    required this.deliveryLocation,
  });

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  bool _isProcessing = false;

  void _confirmOrder() async {
    setState(() => _isProcessing = true);

    final authProvider =
        Provider.of<AuthenticationProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: User not logged in.')),
        );
        setState(() => _isProcessing = false);
      }
      return;
    }

    try {
      final orderData = {
        'userId': user.uid,
        'productName': widget.productName,
        'quantity': widget.quantity,
        'unit': widget.unit,
        'totalCost': widget.totalCost,
        'deliveryLocation': GeoPoint(widget.deliveryLocation.latitude,
            widget.deliveryLocation.longitude),
        'status': 'Processing', // Initial status
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('orders').add(orderData);

      if (!mounted) return;

      // Navigate to Tracking Screen after successful order placement
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              TrackingScreen(deliveryLocation: widget.deliveryLocation),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error confirming order: $e')),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Summary'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review your order details',
              style:
                  theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),

            // Order Details Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _SummaryRow(label: 'Product', value: widget.productName),
                  const Divider(height: 32),
                  _SummaryRow(
                      label: 'Quantity',
                      value:
                          '${widget.quantity.toStringAsFixed(0)} ${widget.unit}'),
                  const Divider(height: 32),
                  _SummaryRow(
                    label: 'Total Cost',
                    value: currencyFormat.format(widget.totalCost),
                    isBold: true,
                    valueColor: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Payment Method Placeholder
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.payment, color: theme.colorScheme.secondary),
                  const SizedBox(width: 16),
                  const Text('Pay with Bank Transfer',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _confirmOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Confirm Order',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: valueColor ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
