import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/buyer_address.dart';
import '../services/buyer_address_service.dart';
import '../theme/app_theme.dart';
import 'map_location_picker_screen.dart';

class AddEditAddressScreen extends StatefulWidget {
  final BuyerAddress? address;

  const AddEditAddressScreen({super.key, this.address});

  @override
  State<AddEditAddressScreen> createState() => _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends State<AddEditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _fullAddressController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();

  double? _latitude;
  double? _longitude;
  bool _isDefault = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.address != null) {
      _labelController.text = widget.address!.label;
      _fullAddressController.text = widget.address!.fullAddress;
      _streetController.text = widget.address!.street ?? '';
      _cityController.text = widget.address!.city ?? '';
      _stateController.text = widget.address!.state ?? '';
      _pincodeController.text = widget.address!.pincode ?? '';
      _latitude = widget.address!.latitude;
      _longitude = widget.address!.longitude;
      _isDefault = widget.address!.isDefault;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _fullAddressController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapLocationPickerScreen(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
          initialAddress: _fullAddressController.text,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latitude = result['latitude'] as double?;
        _longitude = result['longitude'] as double?;
        _fullAddressController.text = result['address'] as String? ?? '';
      });
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final address = BuyerAddress(
        id: widget.address?.id ?? '',
        label: _labelController.text.trim(),
        fullAddress: _fullAddressController.text.trim(),
        street: _streetController.text.trim().isEmpty
            ? null
            : _streetController.text.trim(),
        city: _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        state: _stateController.text.trim().isEmpty
            ? null
            : _stateController.text.trim(),
        pincode: _pincodeController.text.trim().isEmpty
            ? null
            : _pincodeController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        isDefault: _isDefault,
        createdAt: widget.address?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      bool success;
      if (widget.address != null) {
        success = await BuyerAddressService.updateAddress(
          currentUser.uid,
          address,
        );
      } else {
        final addressId = await BuyerAddressService.addAddress(
          currentUser.uid,
          address,
        );
        success = addressId != null;
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.address != null
                  ? 'Address updated successfully'
                  : 'Address added successfully',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save address'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          widget.address != null ? 'Edit Address' : 'Add Address',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.darkText,
          ),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveAddress,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.getCardDecoration(),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _labelController,
                      decoration: AppTheme.getInputDecoration(
                        label: 'Address Label',
                        hint: 'e.g., Home, Work, Office',
                        prefixIcon: Icons.label_outline,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an address label';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _fullAddressController,
                      decoration: AppTheme.getInputDecoration(
                        label: 'Full Address',
                        prefixIcon: Icons.location_on_outlined,
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter the full address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickLocation,
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Pick Location on Map'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: AppTheme.primaryColor),
                          foregroundColor: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _streetController,
                      decoration: AppTheme.getInputDecoration(
                        label: 'Street (Optional)',
                        prefixIcon: Icons.streetview_outlined,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cityController,
                            decoration: AppTheme.getInputDecoration(
                              label: 'City (Optional)',
                              prefixIcon: Icons.location_city_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _stateController,
                            decoration: AppTheme.getInputDecoration(
                              label: 'State (Optional)',
                              prefixIcon: Icons.map_outlined,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _pincodeController,
                      decoration: AppTheme.getInputDecoration(
                        label: 'Pincode (Optional)',
                        prefixIcon: Icons.pin_outlined,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    CheckboxListTile(
                      value: _isDefault,
                      onChanged: (value) {
                        setState(() => _isDefault = value ?? false);
                      },
                      title: const Text('Set as default delivery address'),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

