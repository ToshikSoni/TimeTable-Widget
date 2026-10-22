import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/models.dart';
import '../core/reminders.dart';
import 'alarm_player.dart';

const _snoozeAction = 'snooze';
const _dismissAction = 'dismiss';
const snoozeMinutes = 5;

/// Schedules class reminders, the daily summary, task reminders and the
/// morning alarm.
///
/// On Android notifications are handed to the system ahead of time so they
/// fire even when the app is closed. On desktop the app keeps running in the
/// tray, so a lightweight in-process ticker shows them when they're due —
/// this avoids platform gaps (Linux has no scheduled notifications) and keeps
/// behaviour identical on Windows and Linux.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<String>.broadcast();

  /// The alarm currently ringing, if any. The UI shows a full-screen alarm
  /// while this is non-null.
  final ringing = ValueNotifier<PlannedReminder?>(null);

  bool _ready = false;
  String? _launchPayload;
  List<PlannedReminder> _plan = const [];
  Timer? _ticker;
  DateTime _lastTick = DateTime.now();
  final _fired = <String>{};

  Stream<String> get taps => _taps.stream;
  bool get _android => !kIsWeb && Platform.isAndroid;
  bool get _desktop => !kIsWeb && (Platform.isLinux || Platform.isWindows);

  /// Payload of the notification that launched the app, consumed once.
  String? takeLaunchPayload() {
    final p = _launchPayload;
    _launchPayload = null;
    return p;
  }

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_cadence'),
          linux: LinuxInitializationSettings(defaultActionName: 'Open Cadence'),
          windows: WindowsInitializationSettings(
            appName: 'Cadence',
            appUserModelId: 'io.github.toshiksoni.cadence',
            guid: '63411d22-614a-4f97-b902-85788e0674c3',
          ),
        ),
        onDidReceiveNotificationResponse: _onResponse,
        onDidReceiveBackgroundNotificationResponse: onBackgroundNotificationResponse,
      );
      if (_android) {
        final launch = await _plugin.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp ?? false) {
          _launchPayload = launch!.notificationResponse?.payload;
          if (_launchPayload?.startsWith('alarm:') ?? false) {
            ringing.value = PlannedReminder(
              key: _launchPayload!,
              kind: ReminderKind.alarm,
              at: DateTime.now(),
              title: 'Time to get going',
              body: '',
              payload: _launchPayload,
            );
          }
        }
      }
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  void _onResponse(NotificationResponse r) {
    final payload = r.payload ?? '';
    if (r.actionId == _snoozeAction) {
      snooze();
      return;
    }
    if (r.actionId == _dismissAction) {
      dismissAlarm();
      return;
    }
    _taps.add(payload);
  }

  /// Asks for notification / exact alarm permissions where needed.
  Future<bool> requestPermissions() async {
    if (!_android) return true;
    final a = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final granted = await a?.requestNotificationsPermission() ?? true;
    if (!(await a?.canScheduleExactNotifications() ?? true)) {
      await a?.requestExactAlarmsPermission();
    }
    return granted;
  }

  Future<bool> canScheduleExact() async {
    if (!_android) return true;
    return await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.canScheduleExactNotifications() ??
        true;
  }

  Future<void> requestFullScreenAlarms() async {
    if (!_android) return;
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestFullScreenIntentPermission();
  }

  /// Re-plans all reminders from the current data.
  Future<void> reschedule(AppData data, {bool use24h = true}) async {
    if (!_ready) return;
    final now = DateTime.now();
    _plan = ReminderPlanner.plan(data, from: now, horizon: const Duration(days: 7), use24h: use24h);
    if (_android) await _scheduleAndroid(_plan);
  }

  Future<void> _scheduleAndroid(List<PlannedReminder> plan) async {
    await _plugin.cancelAllPendingNotifications();
    final exact = await canScheduleExact();
    // Android caps pending alarms per app at 500; stay well below.
    for (final r in plan.take(400)) {
      try {
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          payload: r.payload,
          scheduledDate: tz.TZDateTime.from(r.at, tz.UTC),
          notificationDetails: _details(r.kind),
          androidScheduleMode: r.kind == ReminderKind.alarm && exact
              ? AndroidScheduleMode.alarmClock
              : exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('Could not schedule ${r.key}: $e');
      }
    }
  }

  /// Starts the in-process ticker. On Android it only raises the in-app
  /// alarm screen (the system already shows the notification).
  void startTicker() {
    _ticker?.cancel();
    _lastTick = DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) => _tick());
  }

  void _tick() {
    final now = DateTime.now();
    // After sleep/hibernate don't replay a backlog of stale reminders.
    final from = now.difference(_lastTick) > const Duration(minutes: 3)
        ? now.subtract(const Duration(minutes: 2))
        : _lastTick;
    _lastTick = now;
    for (final r in _plan) {
      if (r.at.isAfter(now)) break;
      if (r.at.isBefore(from) || !_fired.add(r.key)) continue;
      if (r.kind == ReminderKind.alarm) {
        ringing.value = r;
        if (_desktop) AlarmPlayer.instance.start();
      }
      if (_desktop) _showNow(r);
    }
  }

  Future<void> _showNow(PlannedReminder r) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: r.id,
        title: r.title,
        body: r.body,
        payload: r.payload,
        notificationDetails: _details(r.kind),
      );
    } catch (e) {
      debugPrint('Could not show notification: $e');
    }
  }

  Future<void> showTest() => _showNow(
    PlannedReminder(
      key: 'test',
      kind: ReminderKind.classSoon,
      at: DateTime.now(),
      title: 'Notifications are working',
      body: 'You will be reminded before each class.',
      payload: 'today',
    ),
  );

  /// Rings the alarm right away; used by "Test alarm" in settings.
  void testAlarm() {
    final r = PlannedReminder(
      key: 'alarm|test',
      kind: ReminderKind.alarm,
      at: DateTime.now(),
      title: 'Time to get going',
      body: 'This is how your morning alarm will look.',
      payload: 'alarm:test',
    );
    ringing.value = r;
    if (_desktop) {
      AlarmPlayer.instance.start();
    } else if (_android && _ready) {
      _plugin.show(
        id: r.id,
        title: r.title,
        body: r.body,
        payload: r.payload,
        notificationDetails: _details(ReminderKind.alarm),
      );
    }
  }

  Future<void> dismissAlarm() async {
    final r = ringing.value;
    ringing.value = null;
    await AlarmPlayer.instance.stop();
    if (r != null && _ready) await _plugin.cancel(id: r.id);
  }

  Future<void> snooze() async {
    final r = ringing.value;
    await dismissAlarm();
    final at = DateTime.now().add(const Duration(minutes: snoozeMinutes));
    final snoozed = PlannedReminder(
      key: 'snooze|${at.millisecondsSinceEpoch}',
      kind: ReminderKind.alarm,
      at: at,
      title: r?.title ?? 'Time to get going',
      body: r?.body ?? '',
      payload: r?.payload ?? 'alarm:snooze',
    );
    if (_android) {
      await _scheduleSnoozeAndroid(_plugin, snoozed);
    } else {
      _plan = [..._plan, snoozed]..sort((a, b) => a.at.compareTo(b.at));
    }
  }

  void dispose() {
    _ticker?.cancel();
    _taps.close();
  }
}

NotificationDetails _details(ReminderKind kind) {
  switch (kind) {
    case ReminderKind.alarm:
      return NotificationDetails(
        android: AndroidNotificationDetails(
          'alarms_v1',
          'Morning alarm',
          channelDescription: 'Wake-up alarm before your first class',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          sound: const RawResourceAndroidNotificationSound('cadence_alarm'),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          // FLAG_INSISTENT: keep ringing until the user reacts.
          additionalFlags: Int32List.fromList([4]),
          ongoing: true,
          autoCancel: false,
          visibility: NotificationVisibility.public,
          actions: const [
            AndroidNotificationAction(_snoozeAction, 'Snooze $snoozeMinutes min'),
            AndroidNotificationAction(_dismissAction, 'Dismiss'),
          ],
        ),
        linux: const LinuxNotificationDetails(
          urgency: LinuxNotificationUrgency.critical,
          category: LinuxNotificationCategory.imReceived,
        ),
      );
    case ReminderKind.summary:
      return const NotificationDetails(
        android: AndroidNotificationDetails(
          'summary_v1',
          'Daily summary',
          channelDescription: 'A morning overview of the day',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      );
    case ReminderKind.task:
      return const NotificationDetails(
        android: AndroidNotificationDetails(
          'tasks_v1',
          'Tasks and exams',
          channelDescription: 'Reminders for assignments, exams and other tasks',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
      );
    case ReminderKind.classSoon:
    case ReminderKind.classStart:
      return const NotificationDetails(
        android: AndroidNotificationDetails(
          'classes_v1',
          'Class reminders',
          channelDescription: 'Heads-up before each class starts',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          sound: RawResourceAndroidNotificationSound('cadence_chime'),
          visibility: NotificationVisibility.public,
        ),
        linux: LinuxNotificationDetails(urgency: LinuxNotificationUrgency.normal),
      );
  }
}

Future<void> _scheduleSnoozeAndroid(
  FlutterLocalNotificationsPlugin plugin,
  PlannedReminder r,
) async {
  final exact =
      await plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.canScheduleExactNotifications() ??
      false;
  await plugin.zonedSchedule(
    id: r.id,
    title: r.title,
    body: r.body,
    payload: r.payload,
    scheduledDate: tz.TZDateTime.from(r.at, tz.UTC),
    notificationDetails: _details(ReminderKind.alarm),
    androidScheduleMode: exact
        ? AndroidScheduleMode.alarmClock
        : AndroidScheduleMode.inexactAllowWhileIdle,
  );
}

/// Handles alarm actions while the app is in the background.
@pragma('vm:entry-point')
Future<void> onBackgroundNotificationResponse(NotificationResponse r) async {
  if (r.actionId != _snoozeAction) return;
  tzdata.initializeTimeZones();
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_cadence'),
    ),
  );
  if (r.id != null) await plugin.cancel(id: r.id!);
  final at = DateTime.now().add(const Duration(minutes: snoozeMinutes));
  await _scheduleSnoozeAndroid(
    plugin,
    PlannedReminder(
      key: 'snooze|${at.millisecondsSinceEpoch}',
      kind: ReminderKind.alarm,
      at: at,
      title: 'Time to get going',
      body: 'Snoozed alarm',
      payload: r.payload ?? 'alarm:snooze',
    ),
  );
}
