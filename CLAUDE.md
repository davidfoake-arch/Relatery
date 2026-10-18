# Relatery

An iPhone app for looking after your relationships: a profile for each
person, their key dates, and reminders before those dates.

SwiftUI + SwiftData, iPhone only, light appearance only. Everything is
stored on the device; there is no account, server or sync.

## Layout

- `Relatery/Models` — `Person` (called a "Relationship" in the interface)
  and `KeyDate` (birthday, wedding anniversary, dating anniversary, or a
  named custom day; the year is optional).
- `Relatery/Views` — the Relationships list, profile, editor, Upcoming and
  reminder settings.
- `Relatery/Reminders` — `ReminderPlanner` decides which notifications
  should be waiting (pure logic, no iOS calls); `ReminderScheduler` hands
  them to iOS; `ReminderSettings` is the user's preferences.
- `Relatery/Theme.swift` — every colour and font.

New `.swift` files and resources under `Relatery/` are picked up by Xcode
automatically; the project file doesn't need editing.

## Visual language

The look is ported from Cairnward (`~/Documents/WeightLog`, see
`Shared/Theme.swift` and the "Visual language" section of its `CLAUDE.md`),
with plum `#74465F` as the primary colour in place of forest green.

Views use `Theme.…` colours and `Theme.Fonts.…` only, and every screen
calls `themedNavigationBar(title:)`, `themedListBackground()` and
`themedRows()`. Cairnward's notes list the iOS quirks behind those helpers.

Cairnward is a separate project. Read it for reference; don't change it.

## Reminders

Local notifications, scheduled non-repeating. iOS keeps at most 64 pending
per app, so only the soonest 60 are queued, and the whole queue is rebuilt
whenever the app becomes active or a date, name or setting changes (see
`ContentView`). Settings are global: on-the-day, one optional heads-up, and
a time of day.

## Next

Roughly in order of value:

1. **Import from Contacts** — pull in names, photos and birthdays so the
   app doesn't have to be filled in by hand.
2. **Gift ideas and notes per person**, beyond the single notes field.
3. **"Last caught up" log**, with nudges for people not spoken to in a
   while.
4. **Backup or sync** — data lives only on the phone. Cairnward's backup
   system (`Backup.swift`, `AutoBackup.swift`) could be adapted.
5. **Automated tests** for `KeyDate` and `ReminderPlanner`. Both have only
   been checked by hand (leap days, year boundaries, future-dated events,
   heads-ups that have already passed). There is no test target yet.

Smaller things noticed along the way:

- Reminder settings apply to every date; no per-person or per-date
  override.
- Dark mode: the palette has no dark variants, which is why the app is
  locked to light.
- If the GitHub repository is ever made public, check the licences of the
  bundled Fraunces and Karla fonts first.
