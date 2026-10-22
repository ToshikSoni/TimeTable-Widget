import 'models.dart';
import 'schedule.dart';

/// Exports a timetable as an iCalendar file, so it can be imported into
/// Google Calendar, Outlook, Thunderbird and friends.
///
/// Classes are expanded into concrete events (rather than RRULEs) so that
/// holidays, "follows Monday" days, groups and cancellations are honoured.
String buildIcs(Timetable tt, {required DateTime from, required DateTime to, DateTime? now}) {
  final stamp = _utc(now ?? DateTime.now());
  final buf = StringBuffer()
    ..writeln('BEGIN:VCALENDAR')
    ..writeln('VERSION:2.0')
    ..writeln('PRODID:-//Cadence//Timetable//EN')
    ..writeln('CALSCALE:GREGORIAN')
    ..writeln('METHOD:PUBLISH')
    ..writeln(_fold('X-WR-CALNAME:${_escape(tt.name)}'));

  for (final o in ScheduleEngine.occurrencesBetween(tt, from, to)) {
    final description = [
      if (o.code.isNotEmpty) o.code,
      if (o.teacher != null) o.teacher!.displayName,
      o.entry.kind.label,
      if (o.entry.group != null) 'Group ${o.entry.group}',
      if (o.entry.note != null) o.entry.note!,
    ].join('\n');
    buf
      ..writeln('BEGIN:VEVENT')
      ..writeln('UID:${o.key.replaceAll('|', '-')}@cadence')
      ..writeln('DTSTAMP:$stamp')
      ..writeln('DTSTART:${_local(o.start)}')
      ..writeln('DTEND:${_local(o.end)}')
      ..writeln(_fold('SUMMARY:${_escape(o.title)}'))
      ..writeln(_fold('DESCRIPTION:${_escape(description)}'));
    if (o.room != null) buf.writeln(_fold('LOCATION:${_escape(o.room!)}'));
    buf.writeln('END:VEVENT');
  }
  buf.writeln('END:VCALENDAR');
  return buf.toString().replaceAll('\n', '\r\n');
}

String _two(int v) => v.toString().padLeft(2, '0');

String _local(DateTime t) =>
    '${t.year}${_two(t.month)}${_two(t.day)}T${_two(t.hour)}${_two(t.minute)}00';

String _utc(DateTime t) {
  final u = t.toUtc();
  return '${_local(u)}Z';
}

String _escape(String s) =>
    s.replaceAll(r'\', r'\\').replaceAll(';', r'\;').replaceAll(',', r'\,').replaceAll('\n', r'\n');

/// Lines longer than 75 octets must be folded (RFC 5545 §3.1).
String _fold(String line) {
  if (line.length <= 74) return line;
  final out = StringBuffer();
  var i = 0;
  while (i < line.length) {
    final end = (i + (i == 0 ? 74 : 73)).clamp(0, line.length);
    if (i > 0) out.write('\n ');
    out.write(line.substring(i, end));
    i = end;
  }
  return out.toString();
}
