# 1% Club

A habit tracker for a small club of friends, built in Flutter for Android and iPhone.

## What's in Phase 1

- **Today:** what's owed today. Tap the circle to mark a habit done, or tap the row to log done, tiny or missed with a remark. Every log has Undo.
- **Plan:** 30-day months with a focus and a "done means" goal. Add habits from any month; they carry over until you set an end. A load meter warns when a month gets too heavy.
- **Build or Maintain:** Build runs on set days. Maintain runs N times a week on any days. Changing a habit's schedule takes effect from today, so past streaks keep their meaning.
- **Streaks with "don't miss twice":** one missed day is forgiven if the next day is kept, at most once a week. Tiny versions count as half and keep the streak.
- **Comeback week:** after 3 or more days away, the app offers 7 days of core habits only.
- **Insights:** a balance avatar across six areas (Physical, Mind, Intellect, Social, Craft, Wealth), level, XP, title, a 10-week heatmap and month-by-month comparison with your partner.
- **Future:** where you'll be at the end of the programme at your pace, or all in.
- **Reminders:** per-habit reminders with Done / Tiny / Snooze buttons that work from the notification, plus evening nudges only while the day is open. There's a cap of 4 a day and quiet hours.
- **Members (admin):** see everyone's last log, month % and level, and add people.
- **Sheet import:** Months 1–2 from the Google Sheet come in as a "Daily check-in". It counts for XP, streaks and history, but not for area strength.

## Rules in numbers

- Day ends at 3 AM, and this can be changed in Settings. Unlogged days stay editable for 48 hours.
- XP: each day is worth 100, split across the habits owed that day. Done earns a full share and tiny earns half. +5 for an honest miss with a note. +50 for a month review.
- Level L costs `100 + 50·(L−1)` XP.
- Area strength (0–100): recency-weighted consistency over 28 days (half-life 14 days), multiplied by coverage, where the target is 4 sessions a week.
- Titles: your strongest area gives The Athlete, Monk, Scholar, Orator, Builder or Investor. Three areas at 30 or more makes you The Polymath. Every active area at 60 or more makes you The Complete Man.

## Code layout

```
lib/core/day.dart           calendar day with the 3 AM cutoff
lib/domain/                 pure rules: models, schedule, streaks, scoring, load, reminders
lib/data/                   Repository interface, local storage, sheet import, auth
lib/state/                  Riverpod providers and the per-person view
lib/services/               notifications and keeping them in sync
lib/features/               screens
test/                       unit tests for the rules
```

Storage sits behind `Repository` and sign-in behind `AuthService`. The local versions keep everything on the phone. Firestore and Google sign-in will implement the same interfaces, so the screens don't change.

## Run it

```
flutter pub get
flutter test
flutter run
```

## Get an APK

Every push to `main` runs `.github/workflows/android.yml`, which builds `app-release.apk`. You can download it from the workflow run's Artifacts. After Firebase is set up, add the `FIREBASE_APP_ID` and `FIREBASE_SERVICE_ACCOUNT` repository secrets. Each build then also goes to the `club` tester group in Firebase App Distribution.
