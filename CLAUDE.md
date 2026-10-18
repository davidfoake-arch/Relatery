# Relatery

An iPhone app for looking after your relationships: a profile for each
person, their key dates, and reminders before those dates.

SwiftUI + SwiftData, iPhone only, light appearance only. Targets iOS 26:
the phones it runs on are on iOS 26, and Xcode won't offer a phone older
than the target, so check them before raising it. Everything is
stored on the device; there is no account, server or sync.

## Layout

- `Relatery/Models` — `Person` (called a "Relationship" in the interface)
  and `KeyDate` (birthday, wedding anniversary, dating anniversary, or a
  named custom day; the year is optional).
- `Relatery/Views` — the Relationships list, profile, editor, Upcoming and
  reminder settings.
- `Relatery/Contacts` — `ContactPicker` (Apple's picker; no Contacts
  permission, the app only receives the people picked) and `ContactCard`,
  a one-off snapshot of a picked contact. Imported people keep
  `Person.contactIdentifier` so they aren't added twice; nothing syncs.
- `Relatery/Reminders` — `ReminderPlanner` decides which reminders should
  be waiting (pure logic, no iOS calls); `ReminderScheduler` hands them to
  iOS and handles the notification buttons; `ReminderAlarms` schedules the
  ones set to Alarm through AlarmKit; `ReminderSettings` is the everyday
  preferences and `ReminderPlan` a custom set of reminders.
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

Which reminders a date gets: its own `ReminderPlan` if it has one, else its
relationship's, else the everyday settings (on-the-day, one heads-up, a time
of day). A plan is a list of rules, each with days before, a time, a
loudness, and whether it keeps reminding.

- **Loudness:** Notification; Time Sensitive (`interruptionLevel`); or
  Alarm, via AlarmKit, which rings through Silent mode and Focus. Time
  Sensitive only takes effect with the
  `com.apple.developer.usernotifications.time-sensitive` entitlement, which
  a free (personal) Apple team can't have; the app is currently signed with
  one, so those arrive as ordinary notifications. Alarms that can't be scheduled (no
  permission) go out as Time Sensitive notifications instead.
- **Keep reminding:** up to 3 follow-ups until "I'm Ready" is tapped on the
  notification. Answers are kept in `ReminderAnswers` so a rebuilt queue
  doesn't bring them back. "Remind Me in 1 Hour" adds a one-off snooze.
- **The queue:** iOS keeps at most 64 pending notifications per app, so only
  the soonest 60 are queued; if more were due, the last one asks for the app
  to be opened. The queue is rebuilt whenever the app becomes active, a date,
  name, plan or setting changes (see `ContentView`), and in a background
  refresh roughly twice a day (`BGTaskSchedulerPermittedIdentifiers`).
- In the Simulator, AlarmKit refuses permission without showing its prompt
  and background refresh doesn't run; both need a real device to test.

## Next

Roughly in order of value:

0. **Priority, once the paid Apple Developer account is approved**
   (enrolment applied for October 2026; until then the app is signed with
   a free personal team):
   - Switch signing to the paid team in Xcode (Signing & Capabilities).
   - Add the Time Sensitive Notifications capability back: a
     `Relatery.entitlements` file with
     `com.apple.developer.usernotifications.time-sensitive` set to true, and
     `CODE_SIGN_ENTITLEMENTS = Relatery.entitlements` in both build
     configurations. It was removed only because free teams can't have it.
   - Build to a phone and check a Time Sensitive reminder gets through a
     Focus. The code already sets `interruptionLevel`; nothing else changes.
   - The paid account also lifts the free account's 7-day limit on apps
     installed from Xcode.
1. **Gift ideas and notes per person**, beyond the single notes field.
2. **"Last caught up" log**, with nudges for people not spoken to in a
   while.
3. **Backup or sync** — data lives only on the phone. Cairnward's backup
   system (`Backup.swift`, `AutoBackup.swift`) could be adapted.
4. **Automated tests** for `KeyDate`, `ReminderPlanner` and `ContactCard`.
   All have only been checked by hand (leap days, year boundaries,
   future-dated events, heads-ups that have already passed, contacts with
   no birth year). There is no test target yet.

Smaller things noticed along the way:

- Contacts import is a snapshot. An "Update from Contacts" button per
  relationship could refresh it without needing Contacts permission.
- Alarms have no snooze: AlarmKit's Repeat button needs a widget extension
  for its countdown. Adding one would allow "Snooze 10 minutes".
- Reminders can't carry a note yet ("Book dinner" two weeks ahead).
- Dark mode: the palette has no dark variants, which is why the app is
  locked to light.
- If the GitHub repository is ever made public, check the licences of the
  bundled Fraunces and Karla fonts first.
