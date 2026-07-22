import 'package:connectivity_plus/connectivity_plus.dart';

/// Wi‑Fi / mobile / other transport up (does not guarantee the API is reachable).
///
/// Samsung and some Android builds report cellular as [ConnectivityResult.other]
/// (or only VPN). Treating only wifi/mobile/ethernet as online incorrectly marks
/// those devices offline while the status bar shows 4G/LTE.
bool connectivityResultsOnline(List<ConnectivityResult> results) {
  if (results.isEmpty) {
    return false;
  }
  if (results.every((r) => r == ConnectivityResult.none)) {
    return false;
  }
  return results.any(
    (r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn ||
        r == ConnectivityResult.other,
  );
}

Future<bool> isDeviceOnline() async {
  final results = await Connectivity().checkConnectivity();
  return connectivityResultsOnline(results);
}
