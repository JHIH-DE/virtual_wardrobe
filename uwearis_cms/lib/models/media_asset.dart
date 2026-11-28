/// How the rights to an image were obtained (backend `MagazineLicenseType`).
enum LicenseType {
  owned('owned', '自己拍攝'),
  commissioned('commissioned', '委託拍攝'),
  brandProvided('brand_provided', '品牌提供'),
  licensedStock('licensed_stock', '付費圖庫'),
  permissionGranted('permission_granted', '取得權利人同意'),

  /// Rights follow the generating tool's terms; the credit names the tool.
  aiGenerated('ai_generated', 'AI 生成'),
  unknown('unknown', '未知');

  final String apiValue;
  final String label;
  const LicenseType(this.apiValue, this.label);

  static LicenseType fromApiValue(Object? value) =>
      values.firstWhere((t) => t.apiValue == value, orElse: () => unknown);
}

/// An image's credit and usage rights (`/admin/magazine/assets`). Content
/// that shows an image can only be published while it's [usable].
class MediaAsset {
  final String objectName;

  /// False until the rights are recorded for the first time.
  final bool exists;
  final String? credit;
  final String? sourceUrl;
  final LicenseType licenseType;
  final String? rightsHolder;
  final String? licenseNote;
  final DateTime? licenseExpiresOn;
  final bool rightsConfirmed;
  final bool usable;

  const MediaAsset({
    required this.objectName,
    this.exists = false,
    this.credit,
    this.sourceUrl,
    this.licenseType = LicenseType.unknown,
    this.rightsHolder,
    this.licenseNote,
    this.licenseExpiresOn,
    this.rightsConfirmed = false,
    this.usable = false,
  });

  /// Confirmed but past its end date.
  bool get expired => rightsConfirmed && !usable;

  factory MediaAsset.fromJson(Map<String, dynamic> json) => MediaAsset(
    objectName: json['object_name'] as String,
    exists: json['exists'] == true,
    credit: json['credit'] as String?,
    sourceUrl: json['source_url'] as String?,
    licenseType: LicenseType.fromApiValue(json['license_type']),
    rightsHolder: json['rights_holder'] as String?,
    licenseNote: json['license_note'] as String?,
    licenseExpiresOn: json['license_expires_on'] is String
        ? DateTime.tryParse(json['license_expires_on'] as String)
        : null,
    rightsConfirmed: json['rights_confirmed'] == true,
    usable: json['usable'] == true,
  );
}

String _date(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// The body of `PUT /admin/magazine/assets`.
Map<String, dynamic> mediaAssetBody({
  required String objectName,
  required String credit,
  required String sourceUrl,
  required LicenseType licenseType,
  required String rightsHolder,
  required String licenseNote,
  required DateTime? licenseExpiresOn,
  required bool rightsConfirmed,
}) => {
  'object_name': objectName,
  'credit': credit.trim(),
  'source_url': sourceUrl.trim().isEmpty ? null : sourceUrl.trim(),
  'license_type': licenseType.apiValue,
  'rights_holder': rightsHolder.trim(),
  'license_note': licenseNote.trim(),
  'license_expires_on': licenseExpiresOn == null
      ? null
      : _date(licenseExpiresOn),
  'rights_confirmed': rightsConfirmed,
};
