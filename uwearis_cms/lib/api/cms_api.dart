import 'dart:typed_data';

import '../models/admin_models.dart';
import '../models/admin_user.dart';
import '../models/media_asset.dart';
import '../models/story_draft.dart';
import 'api_client.dart';

/// An image uploaded to GCS: [objectName] goes into the saved field,
/// [readUrl] shows it before the record is saved.
class UploadedImage {
  final String objectName;
  final String readUrl;
  const UploadedImage(this.objectName, this.readUrl);
}

/// The `/api/v1/admin/*` endpoints (contract: backend docs/magazine_cms.md).
class CmsApi {
  final ApiClient client;
  const CmsApi(this.client);

  static const _contentTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  static String? contentTypeFor(String? extension) =>
      _contentTypes[(extension ?? '').toLowerCase()];

  /// The signed-in account's user id when it is an admin, else null.
  Future<int?> adminUserId() async {
    final me = await client.get('/users/me') as Map<String, dynamic>;
    return me['is_admin'] == true ? (me['id'] as num).toInt() : null;
  }

  Future<UploadedImage> uploadImage(Uint8List bytes, String contentType) async {
    final init =
        await client.post('/admin/uploads/init', {'content_type': contentType})
            as Map<String, dynamic>;
    await client.putToSignedUrl(
      init['upload_url'] as String,
      bytes,
      contentType,
    );
    return UploadedImage(
      init['object_name'] as String,
      init['read_url'] as String,
    );
  }

  // ---- Issues ----

  Future<List<AdminIssue>> listIssues() async => [
    for (final json in await client.get('/admin/magazine/issues') as List)
      AdminIssue.fromJson(json as Map<String, dynamic>),
  ];

  Future<AdminIssue> getIssue(int id) async => AdminIssue.fromJson(
    await client.get('/admin/magazine/issues/$id') as Map<String, dynamic>,
  );

  Future<AdminIssue> saveIssue(int? id, Map<String, dynamic> body) async =>
      AdminIssue.fromJson(
        await (id == null
                ? client.post('/admin/magazine/issues', body)
                : client.put('/admin/magazine/issues/$id', body))
            as Map<String, dynamic>,
      );

  Future<AdminIssue> setIssuePublished(
    int id,
    bool published,
  ) async => AdminIssue.fromJson(
    await client.post(
          '/admin/magazine/issues/$id/${published ? 'publish' : 'unpublish'}',
        )
        as Map<String, dynamic>,
  );

  Future<void> deleteIssue(int id) =>
      client.delete('/admin/magazine/issues/$id');

  Future<List<AdminStorySummary>> reorderStories(
    int issueId,
    List<int> storyIds,
  ) async => [
    for (final json
        in await client.put('/admin/magazine/issues/$issueId/story-order', {
              'story_ids': storyIds,
            })
            as List)
      AdminStorySummary.fromJson(json as Map<String, dynamic>),
  ];

  // ---- Stories ----

  Future<List<AdminStorySummary>> listStories(int issueId) async => [
    for (final json
        in await client.get(
              '/admin/magazine/stories',
              query: {'issue_id': '$issueId'},
            )
            as List)
      AdminStorySummary.fromJson(json as Map<String, dynamic>),
  ];

  Future<StoryDraft> getStory(int id) async => StoryDraft.fromJson(
    await client.get('/admin/magazine/stories/$id') as Map<String, dynamic>,
  );

  Future<StoryDraft> saveStory(StoryDraft draft) async {
    final id = draft.id;
    final body = draft.toJson();
    return StoryDraft.fromJson(
      await (id == null
              ? client.post('/admin/magazine/stories', body)
              : client.put('/admin/magazine/stories/$id', body))
          as Map<String, dynamic>,
    );
  }

  Future<StoryDraft> setStoryPublished(
    int id,
    bool published,
  ) async => StoryDraft.fromJson(
    await client.post(
          '/admin/magazine/stories/$id/${published ? 'publish' : 'unpublish'}',
        )
        as Map<String, dynamic>,
  );

  Future<void> deleteStory(int id) =>
      client.delete('/admin/magazine/stories/$id');

  // ---- Image rights ----

  Future<List<MediaAsset>> listAssets(Iterable<String> objectNames) async {
    final names = objectNames.toSet().toList();
    if (names.isEmpty) return const [];
    return [
      for (final json
          in await client.get(
                '/admin/magazine/assets',
                query: {'object_names': names},
              )
              as List)
        MediaAsset.fromJson(json as Map<String, dynamic>),
    ];
  }

  Future<MediaAsset> saveAsset(Map<String, dynamic> body) async =>
      MediaAsset.fromJson(
        await client.put('/admin/magazine/assets', body)
            as Map<String, dynamic>,
      );

  // ---- Featured items ----

  Future<Paged<AdminItem>> listItems({
    String? query,
    int page = 1,
    int size = 50,
  }) async {
    final data =
        await client.get(
              '/admin/magazine/items',
              query: {
                if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
                'page': '$page',
                'size': '$size',
              },
            )
            as Map<String, dynamic>;
    return Paged([
      for (final json in data['items'] as List)
        AdminItem.fromJson(json as Map<String, dynamic>),
    ], (data['total'] as num).toInt());
  }

  Future<AdminItem> getItem(int id) async => AdminItem.fromJson(
    await client.get('/admin/magazine/items/$id') as Map<String, dynamic>,
  );

  Future<AdminItem> saveItem(int? id, Map<String, dynamic> body) async =>
      AdminItem.fromJson(
        await (id == null
                ? client.post('/admin/magazine/items', body)
                : client.put('/admin/magazine/items/$id', body))
            as Map<String, dynamic>,
      );

  Future<void> deleteItem(int id) => client.delete('/admin/magazine/items/$id');

  // ---- Product catalog ----

  Future<Paged<CatalogProduct>> searchProducts(String query) async {
    final data =
        await client.get(
              '/admin/products',
              query: {
                if (query.trim().isNotEmpty) 'q': query.trim(),
                'size': '30',
              },
            )
            as Map<String, dynamic>;
    return Paged([
      for (final json in data['items'] as List)
        CatalogProduct.fromJson(json as Map<String, dynamic>),
    ], (data['total'] as num).toInt());
  }

  // ---- Users (contract: backend docs/requirements/cms_user_management.md) ----

  Future<Paged<AdminUserSummary>> listUsers({
    String? query,
    bool? isAdmin,
    int page = 1,
    int size = 20,
  }) async {
    final data =
        await client.get(
              '/admin/users',
              query: {
                if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
                if (isAdmin != null) 'is_admin': '$isAdmin',
                'page': '$page',
                'size': '$size',
              },
            )
            as Map<String, dynamic>;
    return Paged([
      for (final json in data['items'] as List)
        AdminUserSummary.fromJson(json as Map<String, dynamic>),
    ], (data['total'] as num).toInt());
  }

  Future<AdminUser> getUser(int id) async => AdminUser.fromJson(
    await client.get('/admin/users/$id') as Map<String, dynamic>,
  );

  /// Only the changed fields; a null value clears that field.
  Future<AdminUser> updateUser(int id, Map<String, Object?> changes) async =>
      AdminUser.fromJson(
        await client.patch('/admin/users/$id', changes) as Map<String, dynamic>,
      );

  /// Permanently deletes the user, as the App's delete account does.
  /// [confirmUserId] must equal [id].
  Future<void> deleteUser(int id, {required int confirmUserId}) => client.post(
    '/admin/users/$id/delete',
    {'confirm_user_id': confirmUserId},
  );

  Future<AdminUser> setUserAdmin(int id, bool isAdmin) async =>
      AdminUser.fromJson(
        await client.put('/admin/users/$id/admin', {'is_admin': isAdmin})
            as Map<String, dynamic>,
      );

  Future<AdminUser> adjustPoints(
    int id, {
    required int delta,
    required String note,
    required String idempotencyKey,
  }) async => AdminUser.fromJson(
    await client.postIdempotent('/admin/users/$id/points/adjust', {
          'delta': delta,
          'note': note,
        }, idempotencyKey: idempotencyKey)
        as Map<String, dynamic>,
  );

  Future<Paged<PointTransaction>> listPointTransactions(
    int id, {
    int page = 1,
    int size = 20,
  }) async {
    final data =
        await client.get(
              '/admin/users/$id/points/transactions',
              query: {'page': '$page', 'size': '$size'},
            )
            as Map<String, dynamic>;
    return Paged([
      for (final json in data['items'] as List)
        PointTransaction.fromJson(json as Map<String, dynamic>),
    ], (data['total'] as num).toInt());
  }

  /// [expiresAt] is Taipei wall-clock time; null cancels the subscription.
  Future<AdminUser> setSubscription(int id, DateTime? expiresAt) async =>
      AdminUser.fromJson(
        await client.put('/admin/users/$id/subscription', {
              'expires_at': expiresAt == null ? null : toTaipeiIso(expiresAt),
            })
            as Map<String, dynamic>,
      );
}
