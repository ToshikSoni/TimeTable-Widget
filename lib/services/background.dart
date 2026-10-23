import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../core/store.dart';
import 'dnd.dart';
import 'home_widget_sync.dart';
import 'notifications.dart';

const _refreshTask = 'cadence.refresh';

/// Android only: a twice-daily background job that keeps the reminder
/// queue and home-screen widgets topped up even if the app isn't opened
/// for a week or more.
class BackgroundRefresh {
  const BackgroundRefresh._();

  static Future<void> register() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await Workmanager().initialize(backgroundDispatcher);
      await Workmanager().registerPeriodicTask(
        _refreshTask,
        _refreshTask,
        frequency: const Duration(hours: 12),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );
    } catch (e) {
      debugPrint('Background refresh unavailable: $e');
    }
  }
}

@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final store = await AppStore.open();
      final use24h = store.settings.use24h ?? true;
      await NotificationService.instance.init();
      await NotificationService.instance.reschedule(store.data, use24h: use24h);
      await HomeWidgetSync.push(store.data, use24h: use24h);
      await DndService.sync(store.data);
      return true;
    } catch (e) {
      debugPrint('Background refresh failed: $e');
      return false;
    }
  });
}
