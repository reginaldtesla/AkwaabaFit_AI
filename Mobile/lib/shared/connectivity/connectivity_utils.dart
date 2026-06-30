import 'package:connectivity_plus/connectivity_plus.dart';

/// Wi‑Fi / mobile data interface up (does not guarantee the API is reachable).
bool connectivityResultsOnline(List<ConnectivityResult> results) {
  return results.contains(ConnectivityResult.wifi) ||
      results.contains(ConnectivityResult.mobile) ||
      results.contains(ConnectivityResult.ethernet);
}

Future<bool> isDeviceOnline() async {
  final results = await Connectivity().checkConnectivity();
  return connectivityResultsOnline(results);
}
