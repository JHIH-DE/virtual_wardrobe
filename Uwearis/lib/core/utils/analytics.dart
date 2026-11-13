import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_storage.dart';
import 'debug_log.dart';

/// Points-charged AI features, as sent in `points_insufficient.feature`.
enum ChargedFeature {
  tryOn('try_on'),
  baseModel('base_model'),
  matchLook('match_look'),
  completeOutfit('complete_outfit'),
  garmentAnalyze('garment_analyze'),
  closetAnalysis('closet_analysis'),
  tripAnalyze('trip_analyze'),
  tripOutfits('trip_outfits');

  const ChargedFeature(this.value);
  final String value;
}

enum TryOnMode {
  newOutfit('new'),
  version('version'),
  regenerate('regenerate');

  const TryOnMode(this.value);
  final String value;
}

enum TryOnStatus {
  success('success'),
  insufficientPoints('insufficient_points'),
  timeout('timeout'),
  error('error');

  const TryOnStatus(this.value);
  final String value;
}

/// Funnel events for Google Analytics. Parameters are fixed enums only —
/// never free text, names, emails or ids beyond the backend user id.
///
/// Native collection is off at launch (Info.plist / AndroidManifest) and only
/// switched on here in non-debug builds, so debug runs and tests send nothing.
class Analytics {
  static FirebaseAnalytics? _instance;

  /// Call after `Firebase.initializeApp()` succeeded.
  static Future<void> initialize() async {
    if (kDebugMode) return;
    try {
      final instance = FirebaseAnalytics.instance;
      await instance.setAnalyticsCollectionEnabled(true);
      _instance = instance;
    } catch (e) {
      debugLog('Analytics unavailable: $e');
    }
  }

  /// Backend user id (the access token's `sub`); null at sign-out.
  static Future<void> setUser(String? accessToken) async {
    final instance = _instance;
    if (instance == null) return;
    try {
      await instance.setUserId(id: AuthStorage.userIdFromToken(accessToken));
    } catch (e) {
      debugLog('Analytics setUser failed: $e');
    }
  }

  /// After account deletion: drops the app instance id so later events
  /// can't be joined to the deleted account.
  static Future<void> resetData() async {
    final instance = _instance;
    if (instance == null) return;
    try {
      await instance.resetAnalyticsData();
    } catch (e) {
      debugLog('Analytics reset failed: $e');
    }
  }

  static void _log(String name, [Map<String, Object>? parameters]) {
    final instance = _instance;
    if (instance == null) return;
    unawaited(
      instance
          .logEvent(name: name, parameters: parameters)
          .catchError((Object e) => debugLog('Analytics $name failed: $e')),
    );
  }

  /// GA's recommended `login` event. [method]: `google` or `apple`.
  static void login(String method) => _log('login', {'method': method});

  static void garmentAdded() => _log('garment_added');

  static void baseModelCreated() => _log('base_model_created');

  static void tryOnStart(TryOnMode mode) =>
      _log('try_on_start', {'mode': mode.value});

  static void tryOnResult(TryOnMode mode, TryOnStatus status) =>
      _log('try_on_result', {'mode': mode.value, 'status': status.value});

  static void pointsInsufficient(ChargedFeature feature) =>
      _log('points_insufficient', {'feature': feature.value});

  static void paywallView() => _log('paywall_view');

  /// [plan]: e.g. `plus`, `pack_2500`.
  static void purchaseTap(String plan) => _log('purchase_tap', {'plan': plan});

  static void tripCreated() => _log('trip_created');

  static void todayOutfitView() => _log('today_outfit_view');
}
