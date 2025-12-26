import 'package:flutter/foundation.dart';

class Look {
  final String id;
  final String occasion;   // 'Casual' / 'Work' / ...
  final String style;      // 'Minimal' / 'Street' / ...
  final String imageUrl;   // try-on image url
  final String? advice;
  final DateTime createdAt;

  Look({
    required this.id,
    required this.occasion,
    required this.style,
    required this.imageUrl,
    this.advice,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class LooksStore extends ChangeNotifier {
  LooksStore._();
  static final LooksStore I = LooksStore._();

  final List<Look> _looks = [];

  List<Look> get looks => List.unmodifiable(_looks);

  void add(Look look) {
    _looks.insert(0, look); // newest first
    notifyListeners();
  }

  void removeById(String id) {
    _looks.removeWhere((l) => l.id == id);
    notifyListeners();
  }

  void clear() {
    _looks.clear();
    notifyListeners();
  }
}