import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/shared/app_update/app_update_info.dart';
import 'package:mobile/shared/app_update/app_version_service.dart';

final appUpdateInfoProvider = FutureProvider<AppUpdateInfo?>((ref) async {
  return AppVersionService.checkForUpdate();
});
