# EHR — Electronic Health Record

Part of **Mini-Hospital 2026**, a teaching hospital built for the course on
hospital, e-health and connected-medical-device informatics.

> Start here if you are new: the
> [course guide](https://github.com/LucaProcaryote/Dev_Central/blob/main/COURSE.md)
> explains how the six repositories fit together and contains the lab exercises.

This application is the clinical record: the patient fiche, the prescriptions
and the notes and observations. It is a Flutter application that runs as a web
app and on Android and iOS from the same code.

## Run it

You need the Flutter SDK (3.24 or newer). Nothing else — no database, no
Docker, no Firebase account.

```bash
flutter pub get
flutter run -d chrome
```

The application starts on the in-memory dataset: twenty fictive patients, their
stays, measurements, prescriptions and notes. A yellow strip across the top
says so, because demo data that looks live is how demonstrations go wrong.

Sign in with any of the accounts listed on the login screen — the password is
not checked in demo mode.

## Languages

Everything is in English, French and Dutch. Use the **EN / FR / NL** switch in
the toolbar; the change is immediate and is remembered on this device.

Two languages are deliberately kept apart:

- the **interface** language, which the clinician chooses;
- the **patient's** preferred language, stored on the fiche, which drives
  printed documents.

Clinical notes are shown in the language they were written in and labelled with
it. They are never machine-translated: a French discharge summary read as
approximate Dutch is a clinical risk, not a convenience.

## What is in it

| Screen | What it does |
|---|---|
| **Patients** | Search by name, medical record number or national register number. Filter to patients currently in the hospital. |
| **Patient fiche → Overview** | Demographics, the current stay, its movement history, and the latest measurement of every vital sign. |
| **Patient fiche → Vital signs** | One chart per measurement over 24 h, 72 h or the whole stay, with the normal range shaded and abnormal readings ringed. |
| **Patient fiche → Prescriptions** | Active and stopped medication, with the allergy check re-run every time the list is drawn. Prescribe, hold, resume or stop. |
| **Patient fiche → Notes** | Admission notes, progress notes, nursing notes, discharge summaries. Write, edit and sign. |
| **Dashboard** | Patients in, free beds, occupancy, and every abnormal measurement across the hospital. |

The allergy banner is pinned above the tabs and repeated in the prescribing
dialog. A high-risk allergy blocks the prescription outright; a low-risk one
has to be acknowledged in writing. Neither can be scrolled past.

## Pointing it at a real backend

Configuration is entirely `--dart-define`, so one build can be aimed anywhere:

```bash
# The local PostgreSQL stack (see the db/ and server/ directories)
flutter run -d chrome --dart-define=BACKEND=restApi --dart-define=API_BASE=http://localhost:8081

# Real Firebase Authentication against the my-hospital-2026 project
flutter run -d chrome --dart-define=AUTH=firebase
```

| Define | Values | Default |
|---|---|---|
| `BACKEND` | `memory`, `restApi`, `dataConnect` | `memory` |
| `AUTH` | `demo`, `firebase` | `demo` |
| `API_BASE` | URL of this application's API | `http://localhost:8081` |
| `FHIR_BASE` | URL of the HAPI FHIR server | `http://localhost:8080/fhir` |
| `EAI_BASE` | URL of the integration engine | `http://localhost:8084` |

Firebase Authentication needs a `lib/firebase_options.dart`, which
`flutterfire configure` generates. It is deliberately git-ignored — it belongs
to your Firebase project, not to this repository.

## Layout

```
lib/
  main.dart                     entry point, fifteen lines
  src/
    ehr_home.dart               navigation
    screens/                    patient list, patient fiche, dashboard
    widgets/                    the prescribing dialog
packages/hospital_core/         the shared foundation (vendored - see below)
```

`hospital_core` holds everything the five applications have in common: the
domain model and its FHIR mapping, the three-language strings, authentication,
the data-access layer and the design system. The canonical copy lives in
**Dev_Central**; every application repository carries an identical vendored
copy so that cloning one repository is enough to run it. Refresh it with:

```bash
./tools/sync_core.sh
```

## Tests

```bash
flutter test
```

The suite signs in, opens a fiche, checks the allergy banner, switches all
three languages, and confirms that a pharmacist is offered neither the
prescribing nor the note-writing action.
