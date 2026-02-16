import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../models/seller_category.dart';
import '../services/seller_verification_service.dart';
import '../services/seller_verification_storage.dart';
import '../theme/app_theme.dart';

class SellerVerificationScreen extends StatefulWidget {
  final SellerCategory? initialCategory;
  
  const SellerVerificationScreen({
    super.key,
    this.initialCategory,
  });

  @override
  State<SellerVerificationScreen> createState() => _SellerVerificationScreenState();
}

class _SellerVerificationScreenState extends State<SellerVerificationScreen> {
  SellerCategory? _selectedCategory;
  
  // Bank Details (Mandatory)
  final TextEditingController _accountHolderNameController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _ifscCodeController = TextEditingController();
  
  // Document storage (local only)
  final Map<String, File?> _uploadedDocuments = {}; // For mobile
  final Map<String, Uint8List?> _uploadedDocumentBytes = {}; // For web
  final Map<String, String> _documentFileNames = {};
  
  // Track uploaded status
  final Map<String, bool> _uploadedDocumentsStatus = {};

  @override
  void initState() {
    super.initState();
    // Set initial category if provided
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory;
    }
    
    // Add listeners to auto-save when requirements are met
    _accountHolderNameController.addListener(_checkAndSaveVerification);
    _bankNameController.addListener(_checkAndSaveVerification);
    _accountNumberController.addListener(_checkAndSaveVerification);
    _ifscCodeController.addListener(_checkAndSaveVerification);
  }
  
  void _checkAndSaveVerification() {
    // Auto-save verification status, bank details, and documents when minimum requirements are met
    if (_selectedCategory != null && _bankDetailsFilled) {
      final mandatoryDocs = SellerVerificationService.getCategoryMandatoryDocuments(_selectedCategory!);
      final allMandatoryUploaded = mandatoryDocs.every(
        (doc) => _uploadedDocumentsStatus[doc] == true,
      );
      
      // Save bank details
      final bankDetails = {
        'accountHolderName': _accountHolderNameController.text,
        'bankName': _bankNameController.text,
        'accountNumber': _accountNumberController.text,
        'ifscCode': _ifscCodeController.text,
      };
      SellerVerificationStorage.saveBankDetails(_selectedCategory!, bankDetails);
      
      // Save documents info
      final documentsMap = <String, String>{};
      for (final entry in _uploadedDocumentsStatus.entries) {
        if (entry.value == true) {
          documentsMap[entry.key] = _documentFileNames[entry.key] ?? 'uploaded';
        }
      }
      SellerVerificationStorage.saveDocuments(_selectedCategory!, documentsMap);
      
      if (allMandatoryUploaded) {
        // Save status automatically when requirements are met
        SellerVerificationStorage.markVerificationCompleted(_selectedCategory!).then((_) {
          debugPrint('✅ Auto-saved verification status for ${_selectedCategory!.name}');
        }).catchError((e) {
          debugPrint('❌ Error auto-saving verification: $e');
        });
      }
    }
  }

  @override
  void dispose() {
    // Remove listeners
    _accountHolderNameController.removeListener(_checkAndSaveVerification);
    _bankNameController.removeListener(_checkAndSaveVerification);
    _accountNumberController.removeListener(_checkAndSaveVerification);
    _ifscCodeController.removeListener(_checkAndSaveVerification);
    
    // Save verification status if minimum requirements are met (synchronously wait)
    // Use a synchronous approach to ensure save completes
    if (_selectedCategory != null && _bankDetailsFilled) {
      final mandatoryDocs = SellerVerificationService.getCategoryMandatoryDocuments(_selectedCategory!);
      final allMandatoryUploaded = mandatoryDocs.every(
        (doc) => _uploadedDocumentsStatus[doc] == true,
      );
      
      if (allMandatoryUploaded) {
        // Save immediately (fire and forget, but will complete)
        SellerVerificationStorage.markVerificationCompleted(_selectedCategory!).then((_) {
          debugPrint('✅ Verification status saved in dispose for ${_selectedCategory!.name}');
        }).catchError((e) {
          debugPrint('❌ Error saving verification in dispose: $e');
        });
      }
    }
    
    _accountHolderNameController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscCodeController.dispose();
    super.dispose();
  }
  
  bool get _bankDetailsFilled {
    return _accountHolderNameController.text.isNotEmpty &&
        _bankNameController.text.isNotEmpty &&
        _accountNumberController.text.isNotEmpty &&
        _ifscCodeController.text.isNotEmpty &&
        _ifscCodeController.text.length == 11;
  }

  bool get _isFullyVerified {
    if (_selectedCategory == null || !_bankDetailsFilled) return false;
    return SellerVerificationService.isFullyVerified(
      _selectedCategory!,
      _uploadedDocumentsStatus,
      _bankDetailsFilled,
    );
  }

  String get _verificationStatus {
    if (_selectedCategory == null) return 'Not Verified';
    return SellerVerificationService.getVerificationStatus(
      _selectedCategory!,
      _uploadedDocumentsStatus,
      _bankDetailsFilled,
    );
  }

  String get _verificationStatusColor {
    if (_selectedCategory == null) return 'grey';
    return SellerVerificationService.getVerificationStatusColor(
      _selectedCategory!,
      _uploadedDocumentsStatus,
      _bankDetailsFilled,
    );
  }

  double get _verificationProgress {
    if (_selectedCategory == null) return 0.0;
    return SellerVerificationService.calculateProgress(
      _selectedCategory!,
      _uploadedDocumentsStatus,
      _bankDetailsFilled,
    );
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Seller Verification',
          style: AppTheme.heading3.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Verification Badge (at top)
              if (_selectedCategory != null) ...[
                _buildVerificationBadge(),
                const SizedBox(height: 24),
              ],

              // Category Selection
              _buildCategorySelection(),
              
              if (_selectedCategory != null) ...[
                const SizedBox(height: 32),
                
                // Bank Details Section (Mandatory)
                _buildBankDetailsSection(),
                
                const SizedBox(height: 32),
                
                // Mandatory Documents Section
                _buildMandatoryDocumentsSection(),
                
                const SizedBox(height: 24),
                
                // Optional Documents Section
                _buildOptionalDocumentsSection(),
                
                const SizedBox(height: 32),
                
                // Continue Button
                _buildContinueButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationBadge() {
    Color badgeColor;
    switch (_verificationStatusColor) {
      case 'green':
        badgeColor = AppTheme.successColor;
        break;
      case 'orange':
        badgeColor = AppTheme.warningColor;
        break;
      default:
        badgeColor = AppTheme.lightText;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: badgeColor,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _isFullyVerified ? Icons.verified : Icons.info_outline,
                color: badgeColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _verificationStatus,
                  style: AppTheme.heading3.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress Bar
          LinearProgressIndicator(
            value: _verificationProgress,
            backgroundColor: AppTheme.borderColor,
            valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text(
            '${(_verificationProgress * 100).toInt()}% Complete',
            style: AppTheme.bodySmall.copyWith(
              color: badgeColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Category',
          style: AppTheme.heading2.copyWith(fontSize: 24),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose the category you want to sell in',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.lightText),
        ),
        const SizedBox(height: 24),
        ...SellerCategory.values.map((category) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildCategoryCard(category),
            )),
      ],
    );
  }

  Widget _buildCategoryCard(SellerCategory category) {
    final isSelected = _selectedCategory == category;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = category;
          // Reset document status when category changes
          _uploadedDocumentsStatus.clear();
          _uploadedDocuments.clear();
          _uploadedDocumentBytes.clear();
          _documentFileNames.clear();
        });
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? category.color : AppTheme.borderColor,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: category.color.withValues(alpha: 0.2),
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
                color: category.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(category.icon, color: category.color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.displayName,
                    style: AppTheme.heading4.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.subtitle,
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
                  color: category.color,
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

  Widget _buildBankDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Bank Details',
              style: AppTheme.heading3,
            ),
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
        ),
        const SizedBox(height: 8),
        Text(
          'Required for all sellers',
          style: AppTheme.bodySmall.copyWith(color: AppTheme.lightText),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.getCardDecoration(),
          child: Column(
            children: [
              _buildTextField(
                controller: _accountHolderNameController,
                label: 'Account Holder Name',
                hint: 'Enter account holder name',
                icon: Icons.person,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _bankNameController,
                label: 'Bank Name',
                hint: 'Enter bank name',
                icon: Icons.account_balance,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _accountNumberController,
                label: 'Account Number',
                hint: 'Enter account number',
                icon: Icons.account_circle,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _ifscCodeController,
                label: 'IFSC Code',
                hint: 'Enter 11-character IFSC code',
                icon: Icons.qr_code,
                maxLength: 11,
                textCapitalization: TextCapitalization.characters,
                onChanged: (value) {
                  setState(() {}); // Trigger rebuild for validation
                },
              ),
              if (_ifscCodeController.text.isNotEmpty &&
                  _ifscCodeController.text.length != 11) ...[
                const SizedBox(height: 8),
                Text(
                  'IFSC code must be 11 characters',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.errorColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
      ),
      keyboardType: keyboardType,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      onChanged: onChanged ?? (value) => setState(() {}),
    );
  }

  Widget _buildMandatoryDocumentsSection() {
    if (_selectedCategory == null) return const SizedBox();
    
    final mandatoryDocs = SellerVerificationService.getCategoryMandatoryDocuments(
      _selectedCategory!,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mandatory Documents',
          style: AppTheme.heading3,
        ),
        const SizedBox(height: 8),
        Text(
          'These documents are required to proceed',
          style: AppTheme.bodySmall.copyWith(color: AppTheme.lightText),
        ),
        const SizedBox(height: 16),
        ...mandatoryDocs.map((docName) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildDocumentCard(
                docName,
                isMandatory: true,
              ),
            )),
      ],
    );
  }

  Widget _buildOptionalDocumentsSection() {
    if (_selectedCategory == null) return const SizedBox();
    
    final optionalDocs = SellerVerificationService.getCategoryOptionalDocuments(
      _selectedCategory!,
    );

    if (optionalDocs.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Optional Verification Documents',
          style: AppTheme.heading3.copyWith(
            color: AppTheme.lightText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Upload these to become a "Verified Seller"',
          style: AppTheme.bodySmall.copyWith(color: AppTheme.lightText),
        ),
        const SizedBox(height: 16),
        ...optionalDocs.map((docName) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildDocumentCard(
                docName,
                isMandatory: false,
              ),
            )),
      ],
    );
  }

  Widget _buildDocumentCard(String docName, {required bool isMandatory}) {
    final isUploaded = _uploadedDocumentsStatus[docName] ?? false;
    final fileName = _documentFileNames[docName];

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
                          docName,
                          style: AppTheme.heading4,
                        ),
                        if (isMandatory) ...[
                          const SizedBox(width: 8),
                          Text(
                            '*',
                            style: TextStyle(
                              color: AppTheme.errorColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.infoColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Optional',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.infoColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isMandatory) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Required document',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.lightText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isUploaded)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.15),
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
                  'Accepted formats: JPG, PNG, PDF',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.lightText,
                    fontSize: 12,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _pickDocument(docName),
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
              if (isUploaded) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _removeDocument(docName),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Remove'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    side: BorderSide(color: AppTheme.errorColor),
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
            ],
          ),
          if (isUploaded && fileName != null) ...[
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
                      fileName,
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

  Widget _buildContinueButton() {
    final mandatoryDocs = _selectedCategory != null
        ? SellerVerificationService.getCategoryMandatoryDocuments(
            _selectedCategory!,
          )
        : <String>[];

    final allMandatoryUploaded = mandatoryDocs.every(
      (doc) => _uploadedDocumentsStatus[doc] == true,
    );

    final canContinue = _bankDetailsFilled && allMandatoryUploaded;

    return Column(
      children: [
        if (!canContinue) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.warningColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: AppTheme.warningColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    !_bankDetailsFilled
                        ? 'Please fill all bank details to continue'
                        : 'Please upload all mandatory documents to continue',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.darkText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: canContinue ? _handleContinue : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Text(
              'Continue',
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        if (!_isFullyVerified && canContinue) ...[
          const SizedBox(height: 12),
          Text(
            'Upload optional documents to become a "Verified Seller"',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.lightText,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Future<void> _pickDocument(String docName) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null && result.files.single.name.isNotEmpty) {
        final pickedFile = result.files.single;

        setState(() {
          if (kIsWeb) {
            if (pickedFile.bytes != null) {
              _uploadedDocumentBytes[docName] = pickedFile.bytes;
              _documentFileNames[docName] = pickedFile.name;
              _uploadedDocumentsStatus[docName] = true;
            }
          } else {
            if (pickedFile.path != null) {
              _uploadedDocuments[docName] = File(pickedFile.path!);
              _documentFileNames[docName] = pickedFile.name;
              _uploadedDocumentsStatus[docName] = true;
            }
          }
        });
        
        // Check and save verification status after document upload
        // Use Future.delayed to ensure setState has completed
        Future.delayed(const Duration(milliseconds: 100), () {
          _checkAndSaveVerification();
        });

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

  void _removeDocument(String docName) {
    setState(() {
      _uploadedDocuments.remove(docName);
      _uploadedDocumentBytes.remove(docName);
      _documentFileNames.remove(docName);
      _uploadedDocumentsStatus[docName] = false;
    });
    
    // Check verification status after removing document
    _checkAndSaveVerification();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document "$docName" removed'),
          backgroundColor: AppTheme.infoColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleContinue() async {
    // Save verification status, bank details, and documents locally
    if (_selectedCategory != null && _bankDetailsFilled) {
      final mandatoryDocs = SellerVerificationService.getCategoryMandatoryDocuments(_selectedCategory!);
      final allMandatoryUploaded = mandatoryDocs.every(
        (doc) => _uploadedDocumentsStatus[doc] == true,
      );
      
      // Save bank details
      final bankDetails = {
        'accountHolderName': _accountHolderNameController.text,
        'bankName': _bankNameController.text,
        'accountNumber': _accountNumberController.text,
        'ifscCode': _ifscCodeController.text,
      };
      await SellerVerificationStorage.saveBankDetails(_selectedCategory!, bankDetails);
      
      // Save documents info (document names as keys, status as values)
      final documentsMap = <String, String>{};
      for (final entry in _uploadedDocumentsStatus.entries) {
        if (entry.value == true) {
          documentsMap[entry.key] = _documentFileNames[entry.key] ?? 'uploaded';
        }
      }
      await SellerVerificationStorage.saveDocuments(_selectedCategory!, documentsMap);
      
      if (allMandatoryUploaded) {
        // Wait for save to complete before navigating
        await SellerVerificationStorage.markVerificationCompleted(_selectedCategory!);
        debugPrint('✅ Verification status saved in Continue for ${_selectedCategory!.name}');
        
        // Verify it was saved
        final isSaved = await SellerVerificationStorage.isVerificationCompleted(_selectedCategory!);
        debugPrint('🔍 Verification status verified after save: $isSaved');
      }
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFullyVerified
                ? '✅ You are now a Verified Seller!'
                : '✅ Verification details saved locally',
          ),
          backgroundColor: AppTheme.successColor,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // Navigate back or to next screen
      Navigator.pop(context);
    }
  }
}

