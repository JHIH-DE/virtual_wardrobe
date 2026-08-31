class ImageEditResult {
  final String imagePath;
  final Map<String, dynamic>? analysisData;
  final Map<String, dynamic>? versatility;

  ImageEditResult({
    required this.imagePath,
    this.analysisData,
    this.versatility,
  });
}
