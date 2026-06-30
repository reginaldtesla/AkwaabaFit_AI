/// Thrown when the scan pipeline decides the image is not a meal.
class NotFoodScanException implements Exception {
  const NotFoodScanException({
    this.title = "This doesn't look like food",
    this.detail =
        'Point your camera at a meal on a plate and scan again.',
  });

  final String title;
  final String detail;

  @override
  String toString() => detail;
}
