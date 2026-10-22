import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart';

import '../core/models.dart';
import '../core/store.dart';

/// Window, tray and autostart integration for Windows and Linux.
class DesktopShell with WindowListener {
  DesktopShell._();
  static final instance = DesktopShell._();

  static bool get supported => !kIsWeb && (Platform.isWindows || Platform.isLinux);

  static const _normalSize = Size(1180, 760);
  static const _minSize = Size(420, 560);

  /// True while the window is shown as the compact desktop widget.
  final widgetMode = ValueNotifier<bool>(false);

  late AppStore _store;
  tray.TrayIcon? _tray;
  tray.MenuItem? _statusItem;
  tray.MenuItem? _widgetItem;
  Rect? _normalBounds;
  bool _quitting = false;

  Settings get _settings => _store.settings;

  Future<void> init(AppStore store, {required bool startHidden, required bool startWidget}) async {
    _store = store;
    await windowManager.ensureInitialized();
    await windowManager.setTitle('Cadence');
    await windowManager.setMinimumSize(_minSize);
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    _setUpAutostart();
    _setUpTray();

    if (startWidget) {
      await enterWidgetMode(show: true);
    } else if (!startHidden) {
      await windowManager.setSize(_normalSize);
      await windowManager.center();
      await windowManager.show();
    }
  }

  // Autostart --------------------------------------------------------------

  void _setUpAutostart() {
    // AppImages run from a temporary mount; autostart must point at the
    // .AppImage file itself.
    final appImage = Platform.environment['APPIMAGE'];
    launchAtStartup.setup(
      appName: 'Cadence',
      appPath: appImage ?? Platform.resolvedExecutable,
      packageName: 'io.github.toshiksoni.cadence',
      args: const ['--hidden'],
    );
  }

  Future<bool> isLaunchAtStartupEnabled() async {
    try {
      return await launchAtStartup.isEnabled();
    } catch (_) {
      return false;
    }
  }

  Future<void> setLaunchAtStartup(bool enabled) async {
    try {
      if (enabled) {
        await launchAtStartup.enable();
      } else {
        await launchAtStartup.disable();
      }
    } catch (e) {
      debugPrint('Autostart change failed: $e');
    }
  }

  // Tray -------------------------------------------------------------------

  void _setUpTray() {
    try {
      final icon = tray.TrayIcon.create();
      if (icon == null) return;
      icon.icon = tray.ImageAsset.fromAsset(
        Platform.isWindows ? 'assets/branding/tray.ico' : 'assets/branding/tray.png',
      );
      icon.setTooltip('Cadence');

      final menu = tray.Menu.create()!;
      _statusItem = tray.MenuItem.createWithLabelAndType(
        'No upcoming classes',
        tray.MenuItemType.normal,
      )?..isEnabled = false;
      menu.addItem(_statusItem);
      menu.addSeparator();
      menu.addItem(_item('Open Cadence', showMainWindow));
      _widgetItem = _item('Show desktop widget', toggleWidgetMode);
      menu.addItem(_widgetItem);
      menu.addSeparator();
      menu.addItem(_item('Quit', quit));

      icon.setContextMenu(menu);
      icon.setContextMenuTrigger(tray.ContextMenuTrigger.rightClicked);
      icon.addListener((event) {
        if (event is tray.TrayIconClickedEvent || event is tray.TrayIconDoubleClickedEvent) {
          showMainWindow();
        }
      });
      icon.setVisible(true);
      _tray = icon;
    } catch (e) {
      debugPrint('Tray unavailable: $e');
    }
  }

  tray.MenuItem? _item(String label, VoidCallback onClick) {
    final item = tray.MenuItem.createWithLabelAndType(label, tray.MenuItemType.normal);
    item?.addListener((event) {
      if (event is tray.MenuItemClickedEvent) onClick();
    });
    return item;
  }

  /// Shows the next class in the tray tooltip and menu.
  void updateStatus(String status) {
    try {
      _tray?.setTooltip('Cadence — $status');
      _statusItem?.label = status;
    } catch (_) {}
  }

  // Window modes ----------------------------------------------------------

  Future<void> showMainWindow() async {
    if (widgetMode.value) await exitWidgetMode();
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> toggleWidgetMode() async {
    if (widgetMode.value) {
      await exitWidgetMode();
    } else {
      await enterWidgetMode();
    }
  }

  Future<void> enterWidgetMode({bool show = true}) async {
    if (!widgetMode.value && await windowManager.isVisible()) {
      _normalBounds = await windowManager.getBounds();
    }
    widgetMode.value = true;
    _widgetItem?.label = 'Hide desktop widget';
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false);
    await windowManager.setMinimumSize(const Size(260, 220));
    await windowManager.setSkipTaskbar(true);
    await windowManager.setSize(Size(_settings.widgetWidth, _settings.widgetHeight));
    if (_settings.widgetX != null && _settings.widgetY != null) {
      await windowManager.setPosition(Offset(_settings.widgetX!, _settings.widgetY!));
    } else {
      await windowManager.setAlignment(Alignment.topRight);
    }
    await applyWidgetLayer();
    await windowManager.setOpacity(_settings.widgetOpacity.clamp(0.4, 1.0));
    if (show) {
      await windowManager.show();
    }
  }

  Future<void> applyWidgetLayer() async {
    if (!widgetMode.value) return;
    final layer = _settings.widgetLayer;
    await windowManager.setAlwaysOnTop(layer == WidgetLayer.onTop);
    try {
      await windowManager.setAlwaysOnBottom(layer == WidgetLayer.onDesktop);
    } catch (_) {}
  }

  Future<void> setWidgetOpacity(double value) async {
    if (widgetMode.value) await windowManager.setOpacity(value.clamp(0.4, 1.0));
  }

  Future<void> exitWidgetMode() async {
    if (!widgetMode.value) return;
    widgetMode.value = false;
    _widgetItem?.label = 'Show desktop widget';
    await windowManager.setAlwaysOnTop(false);
    try {
      await windowManager.setAlwaysOnBottom(false);
    } catch (_) {}
    await windowManager.setOpacity(1);
    await windowManager.setSkipTaskbar(false);
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setMinimumSize(_minSize);
    final bounds = _normalBounds;
    if (bounds != null) {
      await windowManager.setBounds(bounds);
    } else {
      await windowManager.setSize(_normalSize);
      await windowManager.center();
    }
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> hideWidget() async {
    if (!widgetMode.value) return;
    await windowManager.hide();
    widgetMode.value = false;
    _widgetItem?.label = 'Show desktop widget';
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setOpacity(1);
    await windowManager.setSkipTaskbar(false);
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setMinimumSize(_minSize);
    if (_normalBounds != null) await windowManager.setBounds(_normalBounds!);
  }

  Future<void> startDragging() => windowManager.startDragging();

  Future<void> quit() async {
    _quitting = true;
    await _store.flush();
    try {
      _tray?.setVisible(false);
      _tray?.dispose();
    } catch (_) {}
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
    exit(0);
  }

  // WindowListener ----------------------------------------------------------

  @override
  void onWindowClose() async {
    if (_quitting) return;
    if (widgetMode.value) {
      await hideWidget();
      return;
    }
    if (_settings.closeToTray && _tray != null) {
      await windowManager.hide();
    } else {
      await quit();
    }
  }

  @override
  void onWindowMoved() => _rememberWidgetBounds();

  @override
  void onWindowResized() => _rememberWidgetBounds();

  Future<void> _rememberWidgetBounds() async {
    if (!widgetMode.value) return;
    final b = await windowManager.getBounds();
    _store.updateSettings((s) {
      s.widgetX = b.left;
      s.widgetY = b.top;
      s.widgetWidth = b.width;
      s.widgetHeight = b.height;
    });
  }
}
