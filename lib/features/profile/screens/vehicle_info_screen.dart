// lib/features/profile/screens/vehicle_info_screen.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../data/repositories/profile_repository.dart';

class VehicleInfoScreen extends StatefulWidget {
  const VehicleInfoScreen({super.key});

  @override
  State<VehicleInfoScreen> createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends State<VehicleInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _registrationCtr = TextEditingController();
  String _vehicleType = 'motorcycle';
  bool _isLoading = false;
  bool _isSaving = false;

  final _repo = ProfileRepository();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _repo.getProfile();
      if (mounted) {
        _registrationCtr.text = profile.vehicleRegistration;
        if (['motorcycle', 'car', 'van', 'truck']
            .contains(profile.vehicleType)) {
          _vehicleType = profile.vehicleType;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _repo.updateVehicle(
        vehicleType: _vehicleType,
        registration: _registrationCtr.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle info saved'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(dioErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _registrationCtr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Vehicle Information')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vehicle Type',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _vehicleType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.motorcycle_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'motorcycle', child: Text('Motorcycle')),
                        DropdownMenuItem(value: 'car', child: Text('Car')),
                        DropdownMenuItem(value: 'van', child: Text('Van')),
                        DropdownMenuItem(value: 'truck', child: Text('Truck')),
                      ],
                      onChanged: (v) => setState(() => _vehicleType = v!),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _registrationCtr,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Registration Number',
                        hintText: 'e.g. KAA 123B',
                        prefixIcon: Icon(Icons.pin_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Registration number is required'
                          : null,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
