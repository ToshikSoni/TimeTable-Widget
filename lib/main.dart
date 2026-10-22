import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'core/store.dart';
import 'services/background.dart';
import 'services/desktop.dart';
import 'services/notifications.dart';

/// Command-line flags (desktop):
///   --hidden   start in the tray (used when launched at sign-in)
///   --widget   start as the desktop widget
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Platform services (D-Bus, tray, notifications) can fail asynchronously on
  // unusual setups. Log those instead of letting them take the app down.
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Unhandled error: $error\n$stack');
    return true;
  };

  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Plus Jakarta Sans',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });

  final store = await AppStore.open();
  await NotificationService.instance.init();

  if (DesktopShell.supported) {
    final hidden = args.contains('--hidden');
    final settings = store.settings;
    await DesktopShell.instance.init(
      store,
      startHidden: hidden,
      startWidget:
          settings.onboarded && (args.contains('--widget') || (hidden && settings.widgetOnStartup)),
    );
  }

  await BackgroundRefresh.register();
  if (kDebugMode) debugPrint('Cadence data: ${await AppStore.defaultFile()}');

  runApp(CadenceApp(store: store));
}
