import '../models/seller_category.dart';
import '../models/required_document.dart';

class SellerVerificationService {
  /// Returns list of mandatory documents for a given category
  static List<String> getCategoryMandatoryDocuments(SellerCategory category) {
    switch (category) {
      case SellerCategory.cookedFood:
        return [
          'PAN Card',
          'Aadhaar Card',
          'FSSAI License Number',
        ];
      case SellerCategory.liveKitchen:
        return [
          'PAN Card',
          'Aadhaar Card',
          'FSSAI License Number',
        ];
      case SellerCategory.clothesApparel:
        return [
          'PAN Card',
          'Aadhaar Card',
        ];
      case SellerCategory.electronics:
        return [
          'ID Proof',
          'Address Proof',
        ];
      case SellerCategory.electricals:
        return [
          'PAN Card',
          'Aadhaar Card',
        ];
      case SellerCategory.hardware:
        return [
          'PAN Card',
          'Aadhaar Card',
        ];
      case SellerCategory.automobiles:
        return [
          'PAN Card',
          'Aadhaar Card',
        ];
      case SellerCategory.others:
        return [
          'PAN Card',
          'Aadhaar Card',
          'Product Declaration',
        ];
    }
  }

  /// Returns list of optional documents for a given category
  static List<String> getCategoryOptionalDocuments(SellerCategory category) {
    switch (category) {
      case SellerCategory.cookedFood:
        return [
          'Kitchen Hygiene Certificate',
        ];
      case SellerCategory.liveKitchen:
        return [
          'Kitchen Hygiene Certificate',
        ];
      case SellerCategory.clothesApparel:
        return [
          'GST Certificate (if applicable)',
          'Shop Establishment License',
        ];
      case SellerCategory.electronics:
        return [
          'Compliance Declaration',
        ];
      case SellerCategory.electricals:
        return [
          'Safety Compliance',
        ];
      case SellerCategory.hardware:
        return [
          'Trade License',
        ];
      case SellerCategory.automobiles:
        return [
          'Product Authenticity Declaration',
        ];
      case SellerCategory.others:
        return [];
    }
  }

  /// Returns all documents (mandatory + optional) for a category
  static List<String> getCategoryDocuments(SellerCategory category) {
    return [
      ...getCategoryMandatoryDocuments(category),
      ...getCategoryOptionalDocuments(category),
    ];
  }

  /// Creates RequiredDocument list from category
  static List<RequiredDocument> getRequiredDocumentsList(
    SellerCategory category,
    Map<String, bool> uploadedDocuments,
  ) {
    final mandatoryDocs = getCategoryMandatoryDocuments(category);
    final optionalDocs = getCategoryOptionalDocuments(category);

    final List<RequiredDocument> documents = [];

    // Add mandatory documents
    for (final docName in mandatoryDocs) {
      documents.add(
        RequiredDocument(
          name: docName,
          isMandatory: true,
          isUploaded: uploadedDocuments[docName] ?? false,
        ),
      );
    }

    // Add optional documents
    for (final docName in optionalDocs) {
      documents.add(
        RequiredDocument(
          name: docName,
          isMandatory: false,
          isUploaded: uploadedDocuments[docName] ?? false,
        ),
      );
    }

    return documents;
  }

  /// Calculates verification progress (0.0 to 1.0)
  static double calculateProgress(
    SellerCategory category,
    Map<String, bool> uploadedDocuments,
    bool bankDetailsFilled,
  ) {
    final allDocs = getCategoryDocuments(category);
    final uploadedCount = uploadedDocuments.values.where((v) => v).length;
    final totalDocs = allDocs.length;

    // Bank details are mandatory
    if (!bankDetailsFilled) {
      return 0.0;
    }

    // Calculate progress: (uploaded docs / total docs)
    if (totalDocs == 0) return 1.0;
    return (uploadedCount / totalDocs).clamp(0.0, 1.0);
  }

  /// Checks if seller is fully verified
  static bool isFullyVerified(
    SellerCategory category,
    Map<String, bool> uploadedDocuments,
    bool bankDetailsFilled,
  ) {
    if (!bankDetailsFilled) return false;

    final mandatoryDocs = getCategoryMandatoryDocuments(category);
    final optionalDocs = getCategoryOptionalDocuments(category);

    // All mandatory docs must be uploaded
    final allMandatoryUploaded = mandatoryDocs.every(
      (doc) => uploadedDocuments[doc] == true,
    );

    // All optional docs must also be uploaded for "Verified Seller" status
    final allOptionalUploaded = optionalDocs.every(
      (doc) => uploadedDocuments[doc] == true,
    );

    return allMandatoryUploaded && allOptionalUploaded;
  }

  /// Gets verification status text
  static String getVerificationStatus(
    SellerCategory category,
    Map<String, bool> uploadedDocuments,
    bool bankDetailsFilled,
  ) {
    if (isFullyVerified(category, uploadedDocuments, bankDetailsFilled)) {
      return 'Verified Seller';
    }

    final mandatoryDocs = getCategoryMandatoryDocuments(category);
    final mandatoryUploaded = mandatoryDocs.where(
      (doc) => uploadedDocuments[doc] == true,
    ).length;

    if (mandatoryUploaded == mandatoryDocs.length && bankDetailsFilled) {
      return 'Partially Verified';
    }

    return 'Not Verified';
  }

  /// Gets verification status color
  static String getVerificationStatusColor(
    SellerCategory category,
    Map<String, bool> uploadedDocuments,
    bool bankDetailsFilled,
  ) {
    if (isFullyVerified(category, uploadedDocuments, bankDetailsFilled)) {
      return 'green'; // Verified Seller
    }

    final mandatoryDocs = getCategoryMandatoryDocuments(category);
    final mandatoryUploaded = mandatoryDocs.where(
      (doc) => uploadedDocuments[doc] == true,
    ).length;

    if (mandatoryUploaded == mandatoryDocs.length && bankDetailsFilled) {
      return 'orange'; // Partially Verified
    }

    return 'grey'; // Not Verified
  }
}

