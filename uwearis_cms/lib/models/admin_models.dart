import 'package:uwearis/data/magazine.dart';

/// Everything the CMS reads from `/api/v1/admin/*`: both languages, raw
/// object names plus signed URLs for display.
enum PublishStatus {
  draft('draft', '草稿'),
  published('published', '已發佈');

  final String apiValue;
  final String label;
  const PublishStatus(this.apiValue, this.label);

  static PublishStatus fromApiValue(Object? value) =>
      value == 'published' ? published : draft;
}

String? _str(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
int _id(Object? value) => (value as num).toInt();
DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

class AdminIssue {
  final int id;
  final String slug;
  final int? issueNumber;
  final String? titleZhTw;
  final String? titleEn;
  final String? subtitleZhTw;
  final String? subtitleEn;
  final String? coverObjectName;
  final String? coverUrl;
  final PublishStatus status;
  final DateTime? publishedAt;
  final int storyCount;

  const AdminIssue({
    required this.id,
    required this.slug,
    this.issueNumber,
    this.titleZhTw,
    this.titleEn,
    this.subtitleZhTw,
    this.subtitleEn,
    this.coverObjectName,
    this.coverUrl,
    this.status = PublishStatus.draft,
    this.publishedAt,
    this.storyCount = 0,
  });

  String get displayTitle => titleZhTw ?? titleEn ?? slug;

  factory AdminIssue.fromJson(Map<String, dynamic> json) => AdminIssue(
    id: _id(json['id']),
    slug: json['slug'] as String,
    issueNumber: (json['issue_number'] as num?)?.toInt(),
    titleZhTw: _str(json['title_zh_tw']),
    titleEn: _str(json['title_en']),
    subtitleZhTw: _str(json['subtitle_zh_tw']),
    subtitleEn: _str(json['subtitle_en']),
    coverObjectName: _str(json['cover_object_name']),
    coverUrl: _str(json['cover_url']),
    status: PublishStatus.fromApiValue(json['status']),
    publishedAt: _date(json['published_at']),
    storyCount: (json['story_count'] as num?)?.toInt() ?? 0,
  );
}

class AdminStorySummary {
  final int id;
  final int issueId;
  final String slug;
  final String? titleZhTw;
  final String? titleEn;
  final String? coverUrl;
  final MagazineAudience audience;
  final PublishStatus status;
  final DateTime? updatedAt;

  const AdminStorySummary({
    required this.id,
    required this.issueId,
    required this.slug,
    this.titleZhTw,
    this.titleEn,
    this.coverUrl,
    this.audience = MagazineAudience.all,
    this.status = PublishStatus.draft,
    this.updatedAt,
  });

  String get displayTitle => titleZhTw ?? titleEn ?? slug;

  factory AdminStorySummary.fromJson(Map<String, dynamic> json) =>
      AdminStorySummary(
        id: _id(json['id']),
        issueId: _id(json['issue_id']),
        slug: json['slug'] as String,
        titleZhTw: _str(json['title_zh_tw']),
        titleEn: _str(json['title_en']),
        coverUrl: _str(json['cover_url']),
        audience: MagazineAudience.fromApiValue(json['audience'] as String?),
        status: PublishStatus.fromApiValue(json['status']),
        updatedAt: _date(json['updated_at']),
      );
}

class AdminItem {
  final int id;
  final String? nameZhTw;
  final String? nameEn;
  final String? brand;
  final String? category;
  final String? subCategory;
  final String? descriptionZhTw;
  final String? descriptionEn;
  final String? imageObjectName;
  final String? imageUrl;
  final String? tryOnObjectName;
  final String? tryOnUrl;
  final MagazineProduct? product;

  const AdminItem({
    required this.id,
    this.nameZhTw,
    this.nameEn,
    this.brand,
    this.category,
    this.subCategory,
    this.descriptionZhTw,
    this.descriptionEn,
    this.imageObjectName,
    this.imageUrl,
    this.tryOnObjectName,
    this.tryOnUrl,
    this.product,
  });

  String get displayName => nameZhTw ?? nameEn ?? '單品 #$id';

  factory AdminItem.fromJson(Map<String, dynamic> json) => AdminItem(
    id: _id(json['id']),
    nameZhTw: _str(json['name_zh_tw']),
    nameEn: _str(json['name_en']),
    brand: _str(json['brand']),
    category: _str(json['category']),
    subCategory: _str(json['sub_category']),
    descriptionZhTw: _str(json['description_zh_tw']),
    descriptionEn: _str(json['description_en']),
    imageObjectName: _str(json['image_object_name']),
    imageUrl: _str(json['image_url']),
    tryOnObjectName: _str(json['tryon_object_name']),
    tryOnUrl: _str(json['tryon_url']),
    product: json['product'] is Map<String, dynamic>
        ? MagazineProduct.fromJson(json['product'] as Map<String, dynamic>)
        : null,
  );
}

/// A catalog product as `GET /admin/products` lists it (for linking an item).
class CatalogProduct {
  final MagazineProduct product;
  final String productCode;
  final String? imageUrl;

  const CatalogProduct({
    required this.product,
    required this.productCode,
    this.imageUrl,
  });

  factory CatalogProduct.fromJson(Map<String, dynamic> json) {
    final variants = (json['variants'] as List?) ?? const [];
    String? image;
    for (final v in variants.whereType<Map<String, dynamic>>()) {
      final urls = (v['image_urls'] as List?) ?? const [];
      if (urls.isNotEmpty) {
        image = urls.first as String;
        break;
      }
    }
    return CatalogProduct(
      product: MagazineProduct.fromJson(json),
      productCode: json['product_code'] as String? ?? '',
      imageUrl: image,
    );
  }
}

class Paged<T> {
  final List<T> items;
  final int total;
  const Paged(this.items, this.total);
}
