import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/services/wrapped_export_service.dart';

/// The name handed to the gallery must not carry an extension.
///
/// ## Found by saving a card on a device
///
/// `gal` appends `.png` itself — its own documentation says "Do not include the
/// extension" — so passing `cozy_focus_2026_wrapped.png` put
/// `cozy_focus_2026_wrapped.png.png` in the gallery. The file was there, the
/// snackbar said it had saved, and only looking at the device's Pictures folder
/// showed the doubled extension.
///
/// The plugin boundary itself is not covered here: `Gal` talks to the platform
/// and there is no seam to intercept it. What is covered is the transformation
/// that was wrong, which is the part the caller feeds to the plugin.
void main() {
  group('the gallery name has no extension', () {
    test('strips the one the callers used to pass', () {
      expect(
        WrappedExportService.baseName('cozy_focus_2026_wrapped.png'),
        'cozy_focus_2026_wrapped',
      );
      expect(
        WrappedExportService.baseName('cozy_focus_2026_yearly.png'),
        'cozy_focus_2026_yearly',
      );
    });

    test('leaves a name that never had one alone', () {
      expect(WrappedExportService.baseName('photo'), 'photo');
    });

    test('strips only the last extension', () {
      expect(WrappedExportService.baseName('a.b.png'), 'a.b');
    });

    test('a leading dot is a name, not an extension', () {
      expect(WrappedExportService.baseName('.hidden'), '.hidden');
    });
  });
}
