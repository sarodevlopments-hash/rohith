import 'package:flutter/material.dart';
import 'grocery_type.dart';

enum DocumentType {
  aadhaarGovtId,
  bankAccount,
  farmerIdPassbook,
  landOwnershipLease,
  mandiPanchayatCertificate,
  shopTradeLicense,
  gstLicense,
  fssaiLicense,
}

extension DocumentTypeExtension on DocumentType {
  String get displayName {
    switch (this) {
      case DocumentType.aadhaarGovtId:
        return 'Aadhaar / Govt ID';
      case DocumentType.bankAccount:
        return 'Bank Account Details';
      case DocumentType.farmerIdPassbook:
        return 'Farmer ID / Passbook';
      case DocumentType.landOwnershipLease:
        return 'Land Ownership / Lease Document';
      case DocumentType.mandiPanchayatCertificate:
        return 'Mandi / Panchayat Certificate';
      case DocumentType.shopTradeLicense:
        return 'Shop / Trade License';
      case DocumentType.gstLicense:
        return 'GST License';
      case DocumentType.fssaiLicense:
        return 'FSSAI License';
    }
  }
}

class DocumentRequirement {
  final DocumentType type;
  final String name;
  final String description; // Why it's required
  final bool isMandatory;
  final List<String> acceptedFormats; // e.g., ['JPG', 'PNG', 'PDF']

  DocumentRequirement({
    required this.type,
    required this.name,
    required this.description,
    this.isMandatory = true,
    this.acceptedFormats = const ['JPG', 'PNG', 'PDF'],
  });
}

class ComplianceRule {
  final GroceryType groceryType;
  final SellerType? sellerType; // null for packaged groceries
  final String title;
  final List<String> rules; // List of rules/restrictions
  final List<DocumentRequirement> requiredDocuments;
  final String? warningMessage;
  final String? badgeText;
  final Color? badgeColor;
  final bool requiresFssai;

  ComplianceRule({
    required this.groceryType,
    this.sellerType,
    required this.title,
    required this.rules,
    required this.requiredDocuments,
    this.warningMessage,
    this.badgeText,
    this.badgeColor,
    this.requiresFssai = false,
  });
}

class GroceryComplianceService {
  static ComplianceRule getComplianceRule(GroceryType type, SellerType? sellerType) {
    switch (type) {
      case GroceryType.freshProduce:
        if (sellerType == null) {
          throw ArgumentError('SellerType is required for Fresh Produce');
        }
        
        if (sellerType == SellerType.farmer) {
          // CASE 1: Fresh Produce - Farmer
          return ComplianceRule(
            groceryType: type,
            sellerType: sellerType,
            title: 'Fresh Vegetables & Fruits — Farmer',
            rules: [
              'Only raw, unprocessed produce',
              'No cutting, cooking, or packing',
            ],
            requiredDocuments: [
              DocumentRequirement(
                type: DocumentType.aadhaarGovtId,
                name: 'Aadhaar / Govt ID',
                description: 'Required for seller verification',
              ),
              DocumentRequirement(
                type: DocumentType.bankAccount,
                name: 'Bank Account Details',
                description: 'For payment processing',
              ),
              DocumentRequirement(
                type: DocumentType.farmerIdPassbook,
                name: 'Farmer ID / Passbook',
                description: 'Proof of farmer status (any one required)',
                isMandatory: false,
              ),
              DocumentRequirement(
                type: DocumentType.landOwnershipLease,
                name: 'Land ownership / lease document',
                description: 'Proof of farmer status (any one required)',
                isMandatory: false,
              ),
              DocumentRequirement(
                type: DocumentType.mandiPanchayatCertificate,
                name: 'Local mandi / panchayat certificate',
                description: 'Optional proof of farmer status',
                isMandatory: false,
              ),
            ],
            badgeText: 'Verified Farmer',
            badgeColor: const Color(0xFF50C878), // Soft green
            requiresFssai: false,
          );
        } else {
          // CASE 2: Fresh Produce - Reseller
          return ComplianceRule(
            groceryType: type,
            sellerType: sellerType,
            title: 'Fresh Vegetables & Fruits — Reseller',
            rules: [
              'Items must be raw & unprocessed',
              'Source responsibility lies with seller',
            ],
            requiredDocuments: [
              DocumentRequirement(
                type: DocumentType.aadhaarGovtId,
                name: 'Aadhaar / Govt ID',
                description: 'Required for seller verification',
              ),
              DocumentRequirement(
                type: DocumentType.bankAccount,
                name: 'Bank Account Details',
                description: 'For payment processing',
              ),
              DocumentRequirement(
                type: DocumentType.shopTradeLicense,
                name: 'Shop / Trade License',
                description: 'Optional for trade compliance',
                isMandatory: false,
              ),
              DocumentRequirement(
                type: DocumentType.gstLicense,
                name: 'GST',
                description: 'Optional, if applicable',
                isMandatory: false,
              ),
            ],
            badgeText: 'Verified Seller',
            badgeColor: const Color(0xFFFFB703), // Amber
            requiresFssai: false,
          );
        }

      case GroceryType.packagedGroceries:
        // CASE 4: Packaged Food & General Groceries (STRICT COMPLIANCE)
        return ComplianceRule(
          groceryType: type,
          sellerType: null,
          title: 'Packaged Food & General Groceries',
          rules: [
            'All packaged food items must carry valid FSSAI number printed on package',
            'Items without FSSAI labeling are not allowed',
          ],
          requiredDocuments: [
            DocumentRequirement(
              type: DocumentType.aadhaarGovtId,
              name: 'Aadhaar / Govt ID',
              description: 'Required for seller verification',
            ),
            DocumentRequirement(
              type: DocumentType.bankAccount,
              name: 'Bank Account Details',
              description: 'For payment processing',
            ),
            // FSSAI License document upload removed - only warning shown
          ],
          warningMessage:
              'Important: All packaged food and edible grocery items must carry a valid FSSAI number printed on the product package. Items without FSSAI labeling are not allowed to be sold. FSSAI license should be mentioned on the package.',
          badgeText: 'Compliance Verified',
          badgeColor: const Color(0xFF5EC6C6), // Teal
          requiresFssai: false, // Changed to false - no document upload required
        );
    }
  }
}

