import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/ics.dart';
import '../../app_scope.dart';
import '../../theme.dart';

/// Import / export helpers shared by several screens.
class DataActions {
  const DataActions._();

  static String _slug(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');

  /// Saves bytes with a native "Save as" dialog on desktop, or the system
  /// document picker on Android. Returns false when the user cancels.
  static Future<bool> _save(
    BuildContext context, {
    required String fileName,
    required Uint8List bytes,
    required List<String> extensions,
  }) async {
    try {
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save file',
        fileName: fileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: extensions,
      );
      return saved != null;
    } catch (e) {
      if (context.mounted) context.toast('Couldn’t save the file: $e');
      return false;
    }
  }

  static Future<void> exportBackup(BuildContext context) async {
    final json = context.readStore.exportAll();
    final name = 'cadence-backup-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json';
    final ok = await _save(context, fileName: name, bytes: utf8.encode(json), extensions: ['json']);
    if (ok && context.mounted) context.toast('Backup saved');
  }

  static Future<void> shareTimetable(BuildContext context) async {
    final store = context.readStore;
    final tt = store.timetable;
    if (tt == null) return;
    final json = store.exportTimetable(tt);
    final name = '${_slug(tt.name)}.cadence.json';
    if (Platform.isAndroid) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name');
      await file.writeAsString(json);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: tt.name,
          text: 'My timetable for Cadence — open the app and choose Import.',
        ),
      );
      return;
    }
    if (!context.mounted) return;
    final ok = await _save(context, fileName: name, bytes: utf8.encode(json), extensions: ['json']);
    if (ok && context.mounted) {
      context.toast('Saved. Classmates can import it from Settings → Backup & export.');
    }
  }

  static Future<void> importFile(BuildContext context) async {
    try {
      final file = await FilePicker.pickFile(dialogTitle: 'Import Cadence file');
      if (file == null) return;
      final bytes = await file.xFile.readAsBytes();
      if (!context.mounted) return;
      final message = context.readStore.importJson(utf8.decode(bytes));
      context.toast(message);
    } on FormatException {
      if (context.mounted) context.toast('That doesn’t look like a Cadence file');
    } catch (e) {
      if (context.mounted) context.toast('Import failed: $e');
    }
  }

  static Future<void> exportIcs(BuildContext context) async {
    final store = context.readStore;
    final tt = store.timetable;
    if (tt == null) return;
    final now = DateTime.now();
    final from = tt.validFrom != null && tt.validFrom!.isAfter(now)
        ? tt.validFrom!
        : DateTime(now.year, now.month, now.day);
    final to = tt.validUntil ?? from.add(const Duration(days: 120));
    final ics = buildIcs(tt, from: from, to: to);
    final ok = await _save(
      context,
      fileName: '${_slug(tt.name)}.ics',
      bytes: utf8.encode(ics),
      extensions: ['ics'],
    );
    if (ok && context.mounted) {
      context.toast(
        'Calendar file saved — import it into Google Calendar, Outlook or any calendar app',
      );
    }
  }

  static Future<void> exportImage(BuildContext context, RenderRepaintBoundary boundary) async {
    try {
      final image = await boundary.toImage(pixelRatio: 2.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null || !context.mounted) return;
      final tt = context.readStore.timetable;
      final ok = await _save(
        context,
        fileName: '${_slug(tt?.name ?? 'timetable')}.png',
        bytes: data.buffer.asUint8List(),
        extensions: ['png'],
      );
      if (ok && context.mounted) context.toast('Image saved');
    } catch (e) {
      if (context.mounted) context.toast('Couldn’t create the image: $e');
    }
  }
}
