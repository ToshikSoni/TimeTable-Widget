# Cadence user guide

This guide covers everything Cadence can do. If you just want to get going, the
first two sections are enough.

- [Setting up your timetable](#setting-up-your-timetable)
- [Daily use](#daily-use)
- [Widgets](#widgets)
- [Reminders and the wake-up alarm](#reminders-and-the-wake-up-alarm)
- [Lab groups, electives and special days](#lab-groups-electives-and-special-days)
- [Attendance](#attendance)
- [Tasks and exams](#tasks-and-exams)
- [Sharing, backups and calendars](#sharing-backups-and-calendars)
- [Desktop specifics](#desktop-specifics)
- [Troubleshooting](#troubleshooting)

## Setting up your timetable

The quickest way is to let one person in your class type the timetable in and
share it (**Settings → Share timetable**). Everyone else imports the file and
picks their own lab group and electives.

To type one in yourself:

1. **Bell schedule** (*Settings → Bell schedule*). Enter your periods and breaks
   once — for example *Period 1, 09:30–10:30* and *Lunch, 12:30–13:30* marked as
   a break. Cadence starts you off with a typical day you can edit.
2. **Subjects** (*Settings → Subjects*). Name, code (e.g. `CSE2636`), a short
   name for small widgets, a colour, the teacher and the usual room.
3. **Classes** (*Week → + Class*). Pick the subject, tap the days it repeats on
   (you can pick several at once), then tap a period chip. For a two-hour lab,
   tap the next period chip as well — the block extends. Set the room if it
   differs from the subject's usual room, and the group if only one batch
   attends.

Tip: on the desktop you can long-press an empty spot in the week grid to add a
class at that time.

## Daily use

**Today** shows what's happening now with a countdown, what's next, and the rest
of the day. Free periods and breaks appear as dashed gaps. Use the week strip at
the top to look at other days, or the calendar button to jump to any date.

Tap any class to see its details: time, room, teacher (with a one-tap email if
you saved their address), notes, attendance, and actions:

- **Cancel on this date** — the class is struck through for that day only and
  no reminder is sent. Tap *Restore class* to undo.
- **Edit weekly class** — changes every week.
- **Subject settings** — colour, reminder lead time, enrolment.

The **+** button on Today adds a weekly class, an **extra class** for just that
date, a task, or a holiday.

**Week** shows the whole week as a grid, just like the printed timetable. Use the
arrows to move between weeks and the list icon for an agenda view. The **⋮**
menu saves the week as an image, exports a calendar file, or shares the
timetable.

## Widgets

### Android

Long-press an empty spot on your home screen → **Widgets** → **Cadence**, or use
**Settings → Widgets** to add one directly.

- **Up next** (3×2, resizable from 2×1): the class in progress with a progress
  bar, or the next one and how long until it starts.
- **Today** (4×3, resizable): today's classes, with the current one highlighted
  and finished ones dimmed.

The widgets update themselves at every class boundary and at midnight, even when
the app hasn't been opened for days.

### Windows and Linux

Click **Desktop widget** in the sidebar (or in the tray menu). The main window
turns into a compact card you can drag anywhere and resize from its edges. In
**Settings → Widgets** choose whether it stays **on top** of other windows, is
**pinned to the desktop** behind them, or behaves like a normal window, and set
its opacity. Use ⤢ to return to the full app.

If *Start Cadence when I sign in* is on, the widget can appear automatically at
login (*Show widget when Cadence starts at login*).

## Reminders and the wake-up alarm

In **Settings → Reminders & alarms**:

- **Class reminders** — how many minutes before each class. Individual subjects
  can override this or opt out (*Subject → Reminder*).
- **Also notify when class starts** — a second nudge at the start time.
- **Morning summary** — at a time you choose, on days that have classes.
- **Wake-up alarm** — rings a set time before your *first* class of the day.
  It automatically skips holidays, weekends and days that start late. The alarm
  takes over the screen with **I'm up** and **Snooze 5 min**.
- **Task & exam reminders** — per task, from *at the due time* to a week before.

Use **Try it out** to send a test notification or ring the alarm.

On Android 12 and newer, allow **Alarms & reminders** when asked; otherwise the
system may deliver reminders a few minutes late. Cadence shows a warning in
Settings if this permission is missing.

## Lab groups, electives and special days

**Groups** (*Settings → Groups & batches*): add the batches your class is split
into (G1, G2…), then choose yours. Classes marked for another group are hidden
everywhere — views, widgets and reminders. Choose *Show every group* if you're a
teacher or class representative.

**Electives**: in *Settings → Subjects*, switch off subjects you don't take.

**Holidays & special days** (*Settings → Holidays & special days*, or **+** on
Today):

- **Holiday** — no classes and no reminders that day.
- **Follows another day's timetable** — e.g. a working Saturday with Monday's
  classes. Cadence shows a banner and uses that weekday's classes.
- **Note** — classes as usual, with a banner.

**Term dates** (*Settings → Details & dates*): outside these dates the timetable
stays quiet, which is handy for exam weeks and vacations.

## Attendance

Once a class has started, tick **✓** (attended) or **✕** (missed) on it in Today,
or in its details. The **Attendance** tab shows your overall percentage and each
subject's, with advice such as *“You can skip 2 more classes”* or *“Attend the
next 3 classes to reach 75%”*. Change the target from the flag button. Tap a
subject to see and fix its history. *Mark today attended* fills in today's
unmarked classes in one go.

## Tasks and exams

The **Tasks** tab groups everything by when it's due: overdue, today, tomorrow,
this week, later. Swipe right to complete, left to delete (with undo). Tasks due
today show a badge on the tab and also appear on the Today screen.

## Sharing, backups and calendars

All in **Settings → Backup & export**:

- **Share timetable** — a small `.cadence.json` file with subjects, classes,
  groups and holidays (no attendance). Others use **Import** to add it.
- **Back up everything** — every timetable, task, attendance record and setting
  in one file. **Import** a backup to restore it on a new device.
- **Export to calendar** — an `.ics` file with each class as an event, honouring
  holidays, groups and cancellations. Import it into Google Calendar, Outlook,
  Apple Calendar or Thunderbird.
- **Save as image** (*Week → ⋮*) — a PNG of the week grid, perfect for a
  lock-screen wallpaper or a class group chat.

## Desktop specifics

- **Tray icon**: shows the current or next class in its tooltip. Right-click for
  *Open*, *Show desktop widget* and *Quit*.
- **Closing the window** keeps Cadence running in the tray (turn this off in
  *Settings → Startup*). Reminders only arrive while Cadence is running.
- **Start at sign-in**: *Settings → Startup*. Cadence starts quietly in the tray.
- Launching Cadence again while it's running just brings the existing window
  forward.
- Command-line flags: `--hidden` starts in the tray, `--widget` starts as the
  desktop widget.

On **GNOME**, tray icons need the *AppIndicator and KStatusNotifierItem Support*
extension (Ubuntu ships it enabled).

## Troubleshooting

**I don't get reminders on Android.** Check that notifications are allowed for
Cadence, that *Alarms & reminders* is allowed (Android 12+), and that battery
optimisation isn't restricting the app (*Settings → Apps → Cadence → Battery →
Unrestricted*). Some manufacturers (Xiaomi, Oppo, Vivo, Samsung…) are aggressive
about this; [dontkillmyapp.com](https://dontkillmyapp.com) has device-specific
steps.

**I don't get reminders on the desktop.** Cadence must be running — enable
*Start Cadence when I sign in* and *Keep running in the tray when closed*.

**The widget shows “Open Cadence to refresh”.** The widget has run out of
upcoming data (usually after more than a week without the app running in the
background). Opening the app refreshes it.

**Where is my data?** One file called `cadence.json`:

- Windows: `%APPDATA%\Toshik Soni\Cadence\`
- Linux: `~/.local/share/io.github.toshiksoni.cadence/`
- Android: inside the app's private storage (use *Back up everything* to get a copy).

A `cadence.json.bak` with the previous version sits next to it, just in case.

Still stuck? [Open an issue](https://github.com/ToshikSoni/TimeTable-Widget/issues/new/choose).
