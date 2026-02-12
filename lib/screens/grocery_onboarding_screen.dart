import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/grocery_type.dart';
import '../models/grocery_compliance.dart';
import '../models/sell_type.dart'; // For SellType enum
import '../theme/app_theme.dart';
import '../services/seller_profile_service.dart';
import '../services/image_storage_service.dart';
import 'package:url_launcher/url_launcher.dart';
// AddListingScreen is handled by the caller via Navigator.pop result

class GroceryOnboardingScreen extends StatefulWidget {
  const GroceryOnboardingScreen({super.key});

  @override
  State<GroceryOnboardingScreen> createState() => _GroceryOnboardingScreenState();
}

class _GroceryOnboardingScreenState extends State<GroceryOnboardingScreen> {
  int _currentStep = 0;
  GroceryType? _selectedGroceryType;
  SellerType? _selectedSellerType;
  ComplianceRule? _complianceRule;
  final Map<DocumentType, File?> _uploadedDocuments = {}; // For mobile
  final Map<DocumentType, Uint8List?> _uploadedDocumentBytes = {}; // For web
  final Map<DocumentType, String> _documentFileNames = {};
  final Map<DocumentType, String> _existingDocumentUrls = {}; // Previously uploaded document URLs
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadExistingDocuments();
  }

  Future<void> _loadExistingDocuments() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final profile = await SellerProfileService.getProfile(currentUser.uid);
      if (profile != null && profile.groceryDocuments != null) {
        setState(() {
          // Convert string keys to DocumentType enum
          for (final entry in profile.groceryDocuments!.entries) {
            try {
              final docType = DocumentType.values.firstWhere(
                (e) => e.name == entry.key,
                orElse: () => DocumentType.values.first,
              );
              _existingDocumentUrls[docType] = entry.value;
              // Set file names for display
              _documentFileNames[docType] = 'Previously uploaded';
            } catch (e) {
              print('⚠️ Could not parse document type: ${entry.key}');
            }
          }
        });
      }
    } catch (e) {
      print('❌ Error loading existing documents: $e');
    }
  }

  int get _totalSteps {
    // If Fresh Produce is selected, we need seller type step (4 steps total)
    // If Packaged Groceries is selected, skip seller type (3 steps total)
    return _selectedGroceryType == GroceryType.freshProduce ? 4 : 3;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.cardColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.darkText),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          'Grocery Onboarding',
          style: AppTheme.heading3.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: AppTheme.borderColor,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            minHeight: 4,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step Indicator
              _buildStepIndicator(),
              const SizedBox(height: 32),

              // Step Content
              if (_currentStep == 0) _buildStep1CategorySelection(),
              if (_currentStep == 1) _buildStep2SellerType(),
              if (_currentStep == 2) _buildStep3ComplianceAndDocuments(),
              if (_currentStep == 3) _buildStep4Review(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: List.generate(_totalSteps, (index) {
        final isActive = index <= _currentStep;
        final isCompleted = index < _currentStep;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.primaryColor : AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppTheme.successColor
                      : isActive
                          ? AppTheme.primaryColor
                          : AppTheme.borderColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(Icons.check, color: Colors.white, size: 18)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isActive ? Colors.white : AppTheme.lightText,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
              if (index < _totalSteps - 1)
                Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.primaryColor : AppTheme.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  // STEP 1: Category Selection (Simplified)
  Widget _buildStep1CategorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select what you want to sell',
          style: AppTheme.heading2.copyWith(fontSize: 24),
        ),
        const SizedBox(height: 8),
        Text(
          'Document requirements depend on the type of items you sell.',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.lightText),
        ),
        const SizedBox(height: 32),

        // Category Cards (2 options)
        ...GroceryType.values.map((type) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildCategoryCard(type),
            )),

        const SizedBox(height: 24),

        // Info Note
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.infoColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.infoColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: AppTheme.infoColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Homemade edible items must be sold under Cooked Food or Live Food.',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.darkText,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(GroceryType type) {
    final isSelected = _selectedGroceryType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedGroceryType = type;
          _selectedSellerType = null; // Reset seller type when category changes
        });
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? type.color : AppTheme.borderColor,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: type.color.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : AppTheme.getCardDecoration().boxShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: type.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(type.icon, color: type.color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.displayName,
                    style: AppTheme.heading4.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    type.subtitle,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.lightText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: type.color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // STEP 2: Seller Type Selection (Only for Fresh Produce)
  Widget _buildStep2SellerType() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How are you selling these items?',
          style: AppTheme.heading2.copyWith(fontSize: 24),
        ),
        const SizedBox(height: 32),

        // Seller Type Cards
        ...SellerType.values.map((type) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildSellerTypeCard(type),
            )),
      ],
    );
  }

  Widget _buildSellerTypeCard(SellerType type) {
    final isSelected = _selectedSellerType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedSellerType = type;
          // Update compliance rule when seller type is selected
          if (_selectedGroceryType != null) {
            _complianceRule = GroceryComplianceService.getComplianceRule(
              _selectedGroceryType!,
              type,
            );
          }
        });
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : AppTheme.getCardDecoration().boxShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(type.icon, color: AppTheme.primaryColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.displayName,
                    style: AppTheme.heading4.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    type.description,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.lightText,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // STEP 3: Compliance Rules & Document Upload
  Widget _buildStep3ComplianceAndDocuments() {
    // Get compliance rule if not already set
    if (_complianceRule == null && _selectedGroceryType != null) {
      if (_selectedGroceryType == GroceryType.packagedGroceries) {
        _complianceRule = GroceryComplianceService.getComplianceRule(
          _selectedGroceryType!,
          null,
        );
      } else if (_selectedSellerType != null) {
        _complianceRule = GroceryComplianceService.getComplianceRule(
          _selectedGroceryType!,
          _selectedSellerType!,
        );
      }
    }

    if (_complianceRule == null) return const SizedBox();

    final mandatoryDocs = _complianceRule!.requiredDocuments
        .where((doc) => doc.isMandatory)
        .toList();
    final optionalDocs = _complianceRule!.requiredDocuments
        .where((doc) => !doc.isMandatory)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Documents & Compliance Required',
                style: AppTheme.heading2.copyWith(fontSize: 24),
              ),
            ),
            if (_complianceRule!.badgeText != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _complianceRule!.badgeColor?.withOpacity(0.15) ??
                      AppTheme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _complianceRule!.badgeColor ?? AppTheme.primaryColor,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  _complianceRule!.badgeText!,
                  style: TextStyle(
                    color: _complianceRule!.badgeColor ?? AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _complianceRule!.title,
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.lightText),
        ),
        const SizedBox(height: 32),

        // Warning Banner (if applicable) - Non-dismissible for Packaged Groceries
        if (_complianceRule!.warningMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.warningColor.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: AppTheme.warningColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Important:',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.darkText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _complianceRule!.warningMessage!,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.darkText,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Rules List
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.getCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.rule, color: AppTheme.primaryColor, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    'Rules & Restrictions',
                    style: AppTheme.heading4,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._complianceRule!.rules.map((rule) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            rule,
                            style: AppTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Document Upload Section
        Text(
          'Upload Documents',
          style: AppTheme.heading3,
        ),
        const SizedBox(height: 8),
        Text(
          'Accepted formats: JPG, PNG, PDF',
          style: AppTheme.bodySmall.copyWith(color: AppTheme.lightText),
        ),
        const SizedBox(height: 16),

        // Mandatory Documents
        if (mandatoryDocs.isNotEmpty) ...[
          ...mandatoryDocs.map((doc) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildDocumentCard(doc),
              )),
        ],

        // Optional Documents
        if (optionalDocs.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Optional Documents',
            style: AppTheme.heading4.copyWith(
              color: AppTheme.lightText,
            ),
          ),
          const SizedBox(height: 16),
          ...optionalDocs.map((doc) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildDocumentCard(doc),
              )),
        ],
      ],
    );
  }

  Widget _buildDocumentCard(DocumentRequirement doc) {
    final isUploaded = kIsWeb 
        ? (_uploadedDocumentBytes[doc.type] != null || _documentFileNames[doc.type] != null)
        : _uploadedDocuments[doc.type] != null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.getCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          doc.name,
                          style: AppTheme.heading4,
                        ),
                        if (doc.isMandatory) ...[
                          const SizedBox(width: 8),
                          Text(
                            '*',
                            style: TextStyle(
                              color: AppTheme.errorColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doc.description,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.lightText,
                      ),
                    ),
                  ],
                ),
              ),
              if (isUploaded)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: AppTheme.successColor,
                    size: 24,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  doc.acceptedFormats.join(', '),
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.lightText,
                    fontSize: 12,
                  ),
                ),
              ),
              // View button (if existing document)
              if (_existingDocumentUrls[doc.type] != null) ...[
                OutlinedButton.icon(
                  onPressed: () => _viewDocument(doc.type),
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('View'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Upload/Change button
              ElevatedButton.icon(
                onPressed: () => _pickDocument(doc.type),
                icon: Icon(
                  isUploaded ? Icons.refresh : Icons.upload_file,
                  size: 18,
                ),
                label: Text(isUploaded ? 'Change' : 'Upload'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          if (isUploaded && _documentFileNames[doc.type] != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.description,
                      color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _documentFileNames[doc.type]!,
                      style: AppTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // STEP 4: Review & Continue
  Widget _buildStep4Review() {
    if (_complianceRule == null || _selectedGroceryType == null) {
      return const SizedBox();
    }

    final mandatoryDocs = _complianceRule!.requiredDocuments
        .where((doc) => doc.isMandatory)
        .toList();
    final allMandatoryUploaded = mandatoryDocs.every(
        (doc) => _isDocumentUploaded(doc.type));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review & Continue',
          style: AppTheme.heading2.copyWith(fontSize: 24),
        ),
        const SizedBox(height: 8),
        Text(
          'Please review your information before proceeding',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.lightText),
        ),
        const SizedBox(height: 32),

        // Selected Category
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.getCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selected Category',
                style: AppTheme.heading4,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _selectedGroceryType!.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _selectedGroceryType!.icon,
                      color: _selectedGroceryType!.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedGroceryType!.displayName,
                          style: AppTheme.heading4,
                        ),
                        if (_selectedSellerType != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _selectedSellerType!.displayName,
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.lightText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Compliance Rules Accepted
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.getCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified, color: AppTheme.successColor, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    'Compliance Rules Accepted',
                    style: AppTheme.heading4,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Documents Uploaded Summary
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.getCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Documents Uploaded',
                style: AppTheme.heading4,
              ),
              const SizedBox(height: 16),
              ..._complianceRule!.requiredDocuments.map((doc) {
                final isUploaded = _isDocumentUploaded(doc.type);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(
                        isUploaded ? Icons.check_circle : Icons.circle_outlined,
                        color: isUploaded
                            ? AppTheme.successColor
                            : AppTheme.lightText,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          doc.name,
                          style: AppTheme.bodyMedium.copyWith(
                            color: isUploaded
                                ? AppTheme.darkText
                                : AppTheme.lightText,
                          ),
                        ),
                      ),
                      if (!isUploaded && doc.isMandatory)
                        Text(
                          'Required',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.errorColor,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        // Show validation message if documents are missing
        if (!allMandatoryUploaded) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.errorColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.error_outline, color: AppTheme.errorColor, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please upload all required documents to continue.',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.darkText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                // Special message for Fresh Produce - Farmer
                if (_selectedGroceryType == GroceryType.freshProduce &&
                    _selectedSellerType == SellerType.farmer) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 34),
                    child: Text(
                      'Note: At least one farmer proof document is required (Farmer ID, Land ownership, or Mandi certificate).',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.darkText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _currentStep--);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: AppTheme.borderColor, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Back',
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: _currentStep == 0 ? 1 : 2,
              child: ElevatedButton(
                onPressed: (_canProceedToNextStep() && !_isUploading) ? _handleNext : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isUploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _currentStep == _totalSteps - 1
                            ? 'Continue to Add Grocery Items'
                            : 'Continue',
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canProceedToNextStep() {
    switch (_currentStep) {
      case 0:
        return _selectedGroceryType != null;
      case 1:
        // Seller type is only required for Fresh Produce
        if (_selectedGroceryType == GroceryType.freshProduce) {
          return _selectedSellerType != null;
        }
        return true;
      case 2:
        // Check if all mandatory documents are uploaded
        if (_complianceRule == null) return false;
        final mandatoryDocs = _complianceRule!.requiredDocuments
            .where((doc) => doc.isMandatory)
            .toList();
        
        // Special case: For Fresh Produce - Farmer, at least one farmer proof is needed
        // But since they're marked as optional individually, we'll only require basic docs
        // Farmer proof is truly optional per the model definition
        if (_selectedGroceryType == GroceryType.freshProduce &&
            _selectedSellerType == SellerType.farmer) {
          final hasBasicDocs = _isDocumentUploaded(DocumentType.aadhaarGovtId) &&
              _isDocumentUploaded(DocumentType.bankAccount);
          // Farmer proof documents are optional (isMandatory: false)
          // So we only require basic docs
          return hasBasicDocs;
        }
        
        return mandatoryDocs.every((doc) => _isDocumentUploaded(doc.type));
      case 3:
        // Final validation (same as step 2)
        if (_complianceRule == null) return false;
        final mandatoryDocs = _complianceRule!.requiredDocuments
            .where((doc) => doc.isMandatory)
            .toList();
        
        // Special case: For Fresh Produce - Farmer, at least one farmer proof is needed
        // But since they're marked as optional individually, we'll only require basic docs
        // Farmer proof is truly optional per the model definition
        if (_selectedGroceryType == GroceryType.freshProduce &&
            _selectedSellerType == SellerType.farmer) {
          final hasBasicDocs = _isDocumentUploaded(DocumentType.aadhaarGovtId) &&
              _isDocumentUploaded(DocumentType.bankAccount);
          // Farmer proof documents are optional (isMandatory: false)
          // So we only require basic docs
          return hasBasicDocs;
        }
        
        return mandatoryDocs.every((doc) => _isDocumentUploaded(doc.type));
      default:
        return false;
    }
  }

  Future<void> _handleNext() async {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      
      // Update compliance rule when moving to step 3
      if (_currentStep == 2 && _selectedGroceryType != null) {
        if (_selectedGroceryType == GroceryType.packagedGroceries) {
          _complianceRule = GroceryComplianceService.getComplianceRule(
            _selectedGroceryType!,
            null,
          );
        } else if (_selectedSellerType != null) {
          _complianceRule = GroceryComplianceService.getComplianceRule(
            _selectedGroceryType!,
            _selectedSellerType!,
          );
        }
      }
    } else {
      // Save grocery onboarding data to database
      await _saveGroceryOnboardingData();
      
      // Pop back to the previous screen with the groceries result
      // The caller (AddListingScreen or SellerDashboard) will handle applying the type
      if (mounted) {
        Navigator.pop(context, SellType.groceries);
      }
    }
  }

  Future<void> _saveGroceryOnboardingData() async {
    try {
      setState(() => _isUploading = true);

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('⚠️ No user logged in, cannot save grocery onboarding data');
        return;
      }

      if (_selectedGroceryType == null) {
        print('⚠️ No grocery type selected, cannot save');
        return;
      }

      // Upload documents to Firebase Storage
      final documentUrls = <String, String>{}; // Map of document type name -> URL
      
      // Keep existing document URLs
      for (final entry in _existingDocumentUrls.entries) {
        documentUrls[entry.key.name] = entry.value;
      }

      // Upload newly selected documents
      for (final entry in _uploadedDocuments.entries) {
        if (entry.value != null) {
          final url = await ImageStorageService.uploadDocument(
            documentType: entry.key.displayName,
            localPath: entry.value!.path,
            sellerId: currentUser.uid,
          );
          if (url != null) {
            documentUrls[entry.key.name] = url;
            print('✅ Uploaded ${entry.key.displayName}: $url');
          }
        }
      }

      // Upload documents from web (bytes)
      for (final entry in _uploadedDocumentBytes.entries) {
        if (entry.value != null) {
          final url = await ImageStorageService.uploadDocument(
            documentType: entry.key.displayName,
            documentBytes: entry.value,
            sellerId: currentUser.uid,
          );
          if (url != null) {
            documentUrls[entry.key.name] = url;
            print('✅ Uploaded ${entry.key.displayName}: $url');
          }
        }
      }

      // Validate that mandatory documents are uploaded
      if (_complianceRule == null) {
        throw Exception('Compliance rule not found');
      }

      final mandatoryDocTypes = _complianceRule!.requiredDocuments
          .where((doc) => doc.isMandatory)
          .map((doc) => doc.type.name)
          .toList();

      final missingDocs = mandatoryDocTypes.where((docType) => 
        !documentUrls.containsKey(docType)
      ).toList();

      if (missingDocs.isNotEmpty) {
        throw Exception('Please upload all mandatory documents before continuing');
      }

      // Only mark as completed if documents are actually uploaded
      final isCompleted = documentUrls.isNotEmpty && missingDocs.isEmpty;

      // Save grocery onboarding data to seller profile
      await SellerProfileService.updateProfile(
        currentUser.uid,
        groceryType: _selectedGroceryType!.name,
        sellerType: _selectedSellerType?.name,
        groceryOnboardingCompleted: isCompleted,
        groceryDocuments: documentUrls,
      );

      print('✅ Grocery onboarding data saved successfully');
      print('   - Grocery Type: ${_selectedGroceryType!.name}');
      print('   - Seller Type: ${_selectedSellerType?.name ?? 'N/A'}');
      print('   - Documents uploaded: ${documentUrls.length}');
      print('   - Onboarding completed: $isCompleted');
    } catch (e) {
      print('❌ Error saving grocery onboarding data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading documents: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  bool _isDocumentUploaded(DocumentType type) {
    // Check if there's a new upload or an existing document
    if (kIsWeb) {
      return _uploadedDocumentBytes[type] != null || 
             _documentFileNames[type] != null ||
             _existingDocumentUrls[type] != null;
    } else {
      return _uploadedDocuments[type] != null || 
             _existingDocumentUrls[type] != null;
    }
  }

  Future<void> _viewDocument(DocumentType type) async {
    final url = _existingDocumentUrls[type];
    if (url != null) {
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open document')),
            );
          }
        }
      } catch (e) {
        print('❌ Error opening document: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error opening document: $e')),
          );
        }
      }
    }
  }

  Future<void> _pickDocument(DocumentType type) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null && result.files.single.name.isNotEmpty) {
        final pickedFile = result.files.single;
        
        setState(() {
          if (kIsWeb) {
            // On web, use bytes instead of path
            if (pickedFile.bytes != null) {
              _uploadedDocumentBytes[type] = pickedFile.bytes;
              _documentFileNames[type] = pickedFile.name;
            }
          } else {
            // On mobile platforms, use path
            if (pickedFile.path != null) {
              _uploadedDocuments[type] = File(pickedFile.path!);
              _documentFileNames[type] = pickedFile.name;
            }
          }
        });
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File "${pickedFile.name}" selected successfully'),
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
