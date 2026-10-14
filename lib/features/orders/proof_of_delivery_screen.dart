// lib/features/orders/proof_of_delivery_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/location_service.dart';
import '../../core/widgets/gradient_button.dart';
import '../../data/models/delivery_proof.dart';
import '../../data/models/order_model.dart';
import '../../data/providers/order_provider.dart';

/// Completes a delivery with proof: customer code, a drop-off photo, the
/// cylinder swap and — for cash-on-delivery orders — the cash collected.
/// Pops with `true` once the backend has accepted the delivery.
class ProofOfDeliveryScreen extends ConsumerStatefulWidget {
  final String orderId;
  const ProofOfDeliveryScreen({super.key, required this.orderId});

  @override
  ConsumerState<ProofOfDeliveryScreen> createState() =>
      _ProofOfDeliveryScreenState();
}

class _ProofOfDeliveryScreenState extends ConsumerState<ProofOfDeliveryScreen> {
  final _otpCtrl = TextEditingController();
  final _cashCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _picker = ImagePicker();

  XFile? _photo;
  int _emptyCylinders = 0;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pre-fill the cash field with the amount due so the common case — the
    // customer pays exactly what's owed — is a single tap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final order = _find(ref.read(orderProvider));
      if (order != null && order.isCod && _cashCtrl.text.isEmpty) {
        _cashCtrl.text = order.amountDue.toStringAsFixed(0);
      }
    });
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _cashCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  OrderModel? _find(OrderState state) {
    for (final o in state.activeOrders) {
      if (o.id == widget.orderId) return o;
    }
    return null;
  }

  Future<void> _takePhoto() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1280,
        imageQuality: 70, // keeps uploads small on mobile data
      );
      if (picked != null && mounted) {
        setState(() {
          _photo = picked;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not open the camera. Check the camera permission and try again.');
      }
    }
  }

  Future<void> _submit(OrderModel order) async {
    final problem = ProofRules.validate(
      order: order,
      otp: _otpCtrl.text,
      hasPhoto: _photo != null,
      cashText: _cashCtrl.text,
      note: _noteCtrl.text,
    );
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    // Where is the rider? Used both to warn about a far-away confirmation and
    // to give support a record of where the delivery was closed.
    double? lat, lng, distance;
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null) {
      lat = pos.latitude;
      lng = pos.longitude;
      if (order.hasDeliveryLocation) {
        distance = Geolocator.distanceBetween(
            lat, lng, order.deliveryLat, order.deliveryLng);
      }
    }
    if (!mounted) return;

    if (distance != null && distance > ProofRules.geofenceMeters) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Far from the drop-off'),
          content: Text(
            'You appear to be ${distance!.round()} m from the delivery '
            'address. Complete the delivery anyway?',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Go back')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Complete anyway')),
          ],
        ),
      );
      if (go != true) {
        if (mounted) setState(() => _submitting = false);
        return;
      }
    }
    if (!mounted) return;

    final cash = order.isCod
        ? double.tryParse(_cashCtrl.text.replaceAll(',', '').trim())
        : null;

    final proof = DeliveryProof(
      otp: _otpCtrl.text.trim(),
      photoPath: _photo?.path,
      emptyCylindersCollected: _emptyCylinders,
      cashCollected: cash,
      note: _noteCtrl.text,
      latitude: lat,
      longitude: lng,
      distanceFromDropoffM: distance,
    );

    final err = await ref
        .read(orderProvider.notifier)
        .deliverWithProof(order.id, proof);
    if (!mounted) return;

    if (err != null) {
      setState(() {
        _submitting = false;
        _error = err;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final order = _find(ref.watch(orderProvider));

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Proof of delivery')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'This order is no longer active.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Complete #${order.orderNumber}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            // ── Customer code ──────────────────────────────────────────────
            _Card(
              icon: Icons.pin_outlined,
              title: order.otpRequired
                  ? 'Customer delivery code'
                  : 'Customer delivery code (optional)',
              child: TextField(
                controller: _otpCtrl,
                enabled: !_submitting,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                    fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w800),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••',
                  helperText: order.otpRequired
                      ? 'Ask the customer for the code in their AquaGas app.'
                      : 'If the customer has a code, enter it. Otherwise take a photo.',
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Photo ──────────────────────────────────────────────────────
            _Card(
              icon: Icons.photo_camera_outlined,
              title: 'Photo of the delivery',
              child: Column(
                children: [
                  if (_photo != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_photo!.path),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      height: 110,
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: const Text(
                        'Show the cylinder at the customer\'s door',
                        style: TextStyle(color: AppColors.textHint),
                      ),
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _submitting ? null : _takePhoto,
                      icon: Icon(_photo == null
                          ? Icons.photo_camera_outlined
                          : Icons.refresh),
                      label: Text(_photo == null ? 'Take photo' : 'Retake'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Cylinder swap ──────────────────────────────────────────────
            _Card(
              icon: Icons.swap_horiz_rounded,
              title: 'Empty cylinders collected',
              child: Row(
                children: [
                  IconButton.outlined(
                    onPressed: _submitting || _emptyCylinders == 0
                        ? null
                        : () => setState(() => _emptyCylinders--),
                    icon: const Icon(Icons.remove),
                  ),
                  Expanded(
                    child: Text(
                      '$_emptyCylinders',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton.outlined(
                    onPressed: _submitting || _emptyCylinders >= 10
                        ? null
                        : () => setState(() => _emptyCylinders++),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Cash on delivery ───────────────────────────────────────────
            if (order.isCod) ...[
              _Card(
                icon: Icons.payments_outlined,
                title: 'Cash collected',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amount due: KES ${order.amountDue.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _cashCtrl,
                      enabled: !_submitting,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(
                        prefixText: 'KES ',
                        helperText:
                            'This is added to the cash you must remit to AquaGas.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Note ───────────────────────────────────────────────────────
            _Card(
              icon: Icons.notes_outlined,
              title: 'Note (optional)',
              child: TextField(
                controller: _noteCtrl,
                enabled: !_submitting,
                maxLines: 2,
                maxLength: 200,
                decoration: const InputDecoration(
                  hintText: 'Anything support should know about this delivery',
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            GradientButton(
              label: 'Confirm delivery',
              icon: Icons.check_circle_outline,
              loading: _submitting,
              onPressed: _submitting ? null : () => _submit(order),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _Card({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
