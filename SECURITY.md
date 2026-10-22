# Security Policy

## Supported versions

Only the [latest release](https://github.com/ToshikSoni/TimeTable-Widget/releases/latest)
receives security fixes. If you're on an older version, please update first and
check whether the problem is still there.

## Reporting a vulnerability

Please **don't** open a public issue for security problems.

Report it privately through GitHub Security Advisories instead: go to the
[Security tab](https://github.com/ToshikSoni/TimeTable-Widget/security) and
click **Report a vulnerability**. Include:

- the Cadence version and platform (Windows, Linux or Android),
- what the issue is and what an attacker could do with it,
- steps to reproduce, or a proof of concept if you have one.

You should get a reply within a week. Once the issue is confirmed I'll work on
a fix, publish a release, and credit you in the advisory unless you'd rather
stay anonymous.

## Scope

Cadence is an offline app. It has no accounts, no server and no analytics, and
it doesn't send your data anywhere. Your timetable, attendance, tasks and
settings are stored locally on your device; backups and ICS exports are only
written where you choose to save them.

Things that are in scope include, for example:

- importing a crafted backup (JSON) or other file that causes code execution,
  data loss or a crash loop,
- the installer, packages or autostart entry doing something unsafe,
- Android widgets, notifications or exported components leaking data to other
  apps.
