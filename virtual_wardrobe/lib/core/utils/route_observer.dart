import 'package:flutter/material.dart';

/// Registered on [MaterialApp.navigatorObservers] so widgets lower in the
/// tree can react to their route becoming visible again (e.g. after a
/// pushed route above it is popped) via [RouteAware].
final routeObserver = RouteObserver<PageRoute>();
