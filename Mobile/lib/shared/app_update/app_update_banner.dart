import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/shared/app_update/app_update_info.dart';
import 'package:mobile/shared/app_update/app_update_provider.dart';
import 'package:mobile/shared/app_update/app_version_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Dismissible top banner when the API reports a newer store version.
class AppUpdateBannerHost extends ConsumerWidget {
  const AppUpdateBannerHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateAsync = ref.watch(appUpdateInfoProvider);

    return updateAsync.when(
      data: (info) {
        if (info == null || !info.showBanner) {
          return child;
        }
        return Column(
          children: [
            _AppUpdateBanner(
              info: info,
              onDismiss: info.forceUpdate
                  ? null
                  : () async {
                      await AppVersionService.dismissForVersion(
                        info.latestVersion,
                      );
                      ref.invalidate(appUpdateInfoProvider);
                    },
            ),
            Expanded(child: child),
          ],
        );
      },
      loading: () => child,
      error: (_, _) => child,
    );
  }
}

class _AppUpdateBanner extends StatelessWidget {
  const _AppUpdateBanner({
    required this.info,
    this.onDismiss,
  });

  final AppUpdateInfo info;
  final VoidCallback? onDismiss;

  Future<void> _openStore() async {
    final uri = Uri.tryParse(info.storeUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    const primary = Color(0xFF1A5D1A);

    return Material(
      elevation: 4,
      color: const Color(0xFFE8F5E9),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, topPad + 8, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.system_update, color: primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.forceUpdate
                        ? 'Update required'
                        : 'Update available',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1B4332),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    info.message,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.3,
                      color: Colors.blueGrey.shade800,
                    ),
                  ),
                  if (!info.forceUpdate) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Version ${info.latestVersion} is on the store.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.blueGrey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            TextButton(
              onPressed: _openStore,
              style: TextButton.styleFrom(
                foregroundColor: primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                'Update',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: Colors.blueGrey.shade600,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onDismiss,
                tooltip: 'Dismiss',
              ),
          ],
        ),
      ),
    );
  }
}
