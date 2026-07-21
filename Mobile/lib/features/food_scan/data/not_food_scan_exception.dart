/// Thrown when the scan pipeline decides the image is not a meal.
class NotFoodScanException implements Exception {
  const NotFoodScanException({
    this.title = 'Not recognized',
  });

  final String title;

  @override
  String toString() => title;
}
