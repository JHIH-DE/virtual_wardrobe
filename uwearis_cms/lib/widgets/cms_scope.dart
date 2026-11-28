import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/cms_api.dart';

/// Gives every page the signed-in [CmsApi]; rebuilds on sign-in / sign-out.
class CmsScope extends InheritedNotifier<ApiClient> {
  final CmsApi api;

  CmsScope({super.key, required this.api, required super.child})
    : super(notifier: api.client);

  static CmsApi of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CmsScope>()!.api;

  static CmsApi read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CmsScope>()!.api;
}
