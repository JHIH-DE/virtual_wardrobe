import 'versatility.dart';

class ImageEditResult {
  final String imagePath;
  final Map<String, dynamic>? analysisData;
  final Versatility? versatility;

  ImageEditResult({
    required this.imagePath,
    this.analysisData,
    this.versatility,
  });
}
