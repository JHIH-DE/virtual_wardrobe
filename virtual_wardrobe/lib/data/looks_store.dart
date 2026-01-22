import 'package:flutter/foundation.dart';
import '../features/garment_category.dart';

class Look {
  final String id;
  final String seasons;   // 'Casual' / 'Work' / ...
  final String style;      // 'Minimal' / 'Street' / ...
  final String imageUrl;   // try-on image url
  final String? advice;
  final DateTime createdAt;
  final List<Garment> items;

  Look({
    required this.id,
    required this.seasons,
    required this.style,
    required this.imageUrl,
    this.advice,
    this.items = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class LooksStore extends ChangeNotifier {
  LooksStore._();
  static final LooksStore I = LooksStore._();

  final List<Look> _looks = [];

  List<Look> get looks => List.unmodifiable(_looks);

  void add(Look look) {
    _looks.insert(0, look);
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