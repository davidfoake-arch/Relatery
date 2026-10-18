# Relatery

An iPhone app for looking after your relationships: a profile for each
person, their key dates, and reminders before those dates.

SwiftUI + SwiftData, iPhone only, light and dark appearance. Targets iOS 26:
the phones it runs on are on iOS 26, and Xcode won't offer a phone older
than the target, so check them before raising it. Everything is
stored on the device; there is no account, server or sync.

## Layout

- `Relatery/Models` — `Person` (called a "Relationship" in the interface)
  and `KeyDate` (birthday, wedding anniversary, dating anniversary, or a
  named custom day; the year is optional), plus `GiftIdea` (idea → bought →
  given, kept as a history) and `NoteEntry` (dated notes). The old single
  `Person.notes` field is only read by `LegacyNotes`, which turns it into a
  first dated note at launch.
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

### Dark mode ("Night plum")

Dark mode, stage 1: the sibling of Cairnward's "Night forest", with plum in
place of forest. Each `Theme` colour has a light and a dark value, built by
`adaptive(light:dark:)` in `Theme.swift`; iOS picks one as it draws.

| Role (`Theme` name) | Light | Dark |
|---|---|---|
| `plum` — filled shapes (avatars, ticked circles, swipe buttons) | `#74465F` | `#9C5179` |
| `accent` — plum as text, icons, `.tint` | `#74465F` | `#C28CA9` |
| `navigationBar` | `#74465F` | same |
| `deepPlum` | `#543245` | `#5C2E47` |
| `cream` — screen background | `#F3ECDC` | `#1A1116` |
| `warmWhite` — cards, rows | `#FBF8F1` | `#261A21` |
| `darkBrown` — main text (same as Cairnward) | `#3A2B22` | `#EDE4D1` |
| `mutedBrown` — secondary text (plum-tinted) | `#6B5748` | `#A38E99` |
| `stone` — dividers only | `#DFD5C3` | `#3B2D35` |
| `clay` — clay as text and icons | `#B5653F` | `#C8774C` |
| `clayFill` — clay buttons with cream text | `#B5653F` | same |
| `onPlum` — text and symbols on a plum or clay fill | `#F3ECDC` | same |
| `berry` — destructive (brick red, lifted at night) | `#B3302B` | `#D85F5B` |

Rules:
- Plum as text, an icon or a `.tint` is `accent`; plum as a filled shape
  (including a swipe action's `.tint`) is `plum`; the bar is
  `navigationBar`. Anything on a plum or clay fill uses `onPlum`, never the
  adaptive `cream`, which goes dark at night.
- The app follows the phone's setting. No in-app switch, and never
  `.preferredColorScheme`: it overrides the bar's dark scheme and turns the
  status bar black on plum.
- A `*.fill` symbol on a coloured shape (the ticked circle in Add from
  Contacts) is drawn with `.symbolRenderingMode(.palette)`, so its tick is
  cream rather than a hole showing the row through it.
- Anything that has to be seen, like an empty circle, uses `mutedBrown`,
  not `stone`.
- Relatery's own calls, beyond Cairnward's recipe: the red is lifted at
  night to keep 4.5 : 1 on a card; clay buttons keep the light clay so
  their cream text stays readable; the launch background has a dark
  variant (`LaunchBackground` colour asset). The app has no shared
  pictures yet; if it gets any, render them light.

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

## Where we are (18 October 2026)

Working and tested on David's phone:

- Relationships with photos, types (including Pet) and key dates.
- Selective import from Contacts (pick, review, confirm), and "Fill from
  Contacts" in the editor.
- Reminders: everyday settings for everyone, custom plans per person and
  per date, the "Important" set, alarms, and "keep reminding" with
  I'm Ready / Remind Me in 1 Hour.
- Gift ideas (idea → bought → given, with a Given history) and dated notes
  on each profile.
- Dark mode ("Night plum"), matching Cairnward.

Waiting on the paid developer account: Time Sensitive reminders currently
arrive as ordinary notifications, which includes most of the "Important"
set (see item 0 below). Until then, run the app from Xcode at least weekly:
free-account installs stop opening after 7 days.

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
1. **Capture from anywhere** — a Share option (messages, screenshots,
   links) and a Siri / Shortcuts action to add a note or gift idea for
   someone, without opening the app.
2. **Gift suggestions** — on phones with Apple Intelligence, Apple's
   on-device model (FoundationModels) reads a person's notes and suggests
   ideas for the next date, showing which note each came from. Not
   available on an iPhone 15 Plus. iOS doesn't let apps read Messages, so
   texts only get in through the Share option above.
3. **"Last caught up" log**, with nudges for people not spoken to in a
   while.
4. **Backup or sync** — data lives only on the phone. Cairnward's backup
   system (`Backup.swift`, `AutoBackup.swift`) could be adapted.
5. **Automated tests** for `KeyDate`, `ReminderPlanner` and `ContactCard`.
   All have only been checked by hand (leap days, year boundaries,
   future-dated events, heads-ups that have already passed, contacts with
   no birth year). There is no test target yet.

Smaller things noticed along the way:

- Contacts import is a snapshot. An "Update from Contacts" button per
  relationship could refresh it without needing Contacts permission.
- Alarms have no snooze: AlarmKit's Repeat button needs a widget extension
  for its countdown. Adding one would allow "Snooze 10 minutes".
- Reminders can't carry a note yet ("Book dinner" two weeks ahead).
- If the GitHub repository is ever made public, check the licences of the
  bundled Fraunces and Karla fonts first.
