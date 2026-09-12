import 'package:ehr_app/src/ehr_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_core/hospital_core.dart';

/// Builds the application against a fixed in-memory dataset, already signed in
/// as the given role, so each test starts on the screen it is about.
Future<void> pumpEhr(
  WidgetTester tester, {
  UserRole role = UserRole.physician,
  Locale locale = const Locale('en'),
}) async {
  final repository = MemoryHospitalRepository(
    seed: HospitalSeed.build(now: DateTime.utc(2026, 9, 12, 10)),
  );
  final auth = DemoAuthService();
  await auth.initialize();
  await auth.signInAs(seedUsers.firstWhere((u) => u.role == role));

  await tester.pumpWidget(
    MiniHospitalApp(
      config: const AppConfig(
        app: HospitalApp.ehr,
        backendMode: BackendMode.memory,
        authMode: AuthMode.demo,
        apiBaseUrl: '',
        fhirBaseUrl: '',
        eaiBaseUrl: '',
      ),
      title: (l10n) => l10n.appTitleEhr,
      homeBuilder: (context) => const EhrHome(),
      repositoryOverride: repository,
      authOverride: auth,
      localeStore: InMemoryLocaleStore(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Opens a patient's file by searching for them, which is both how a clinician
/// actually does it and immune to the patient being below the list fold.
Future<void> openPatient(WidgetTester tester, String surname) async {
  await tester.enterText(find.byType(TextField).first, surname);
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(surname.toUpperCase()).first);
  await tester.pumpAndSettle();
}

void main() {
  // A wide window so the master-detail layout is exercised.
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('signs in and lists the patients', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpEhr(tester);

    expect(find.text('Electronic Health Record'), findsOneWidget);
    // Family-name-first list entries, alphabetical.
    expect(find.textContaining('AMRANI'), findsOneWidget);
    expect(find.textContaining('DE SMET'), findsOneWidget);
    // The ward and bed appear for admitted patients only.
    expect(find.textContaining('Intensive care unit'), findsWidgets);
  });

  testWidgets('shows the sign-in screen when nobody is signed in', (
    tester,
  ) async {
    final repository = MemoryHospitalRepository(
      seed: HospitalSeed.build(now: DateTime.utc(2026, 9, 12, 10)),
    );
    final auth = DemoAuthService();

    await tester.pumpWidget(
      MiniHospitalApp(
        config: const AppConfig(
          app: HospitalApp.ehr,
          backendMode: BackendMode.memory,
          authMode: AuthMode.demo,
          apiBaseUrl: '',
          fhirBaseUrl: '',
          eaiBaseUrl: '',
        ),
        title: (l10n) => l10n.appTitleEhr,
        homeBuilder: (context) => const EhrHome(),
        repositoryOverride: repository,
        authOverride: auth,
        localeStore: InMemoryLocaleStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
    // The demo mode must announce itself rather than look like real security.
    expect(find.text('Demo mode'), findsOneWidget);
  });

  testWidgets('opens a patient file with its allergy banner', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpEhr(tester);
    await openPatient(tester, 'Van Damme');

    // Émile Van Damme has one high-risk penicillin allergy.
    expect(find.text('1 allergy on file'), findsOneWidget);
    expect(find.text('Penicillin'), findsWidgets);
    expect(find.text('MRN000001'), findsWidgets);
  });

  testWidgets('the interface switches language without a restart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpEhr(tester);
    expect(find.text('Patients'), findsWidgets);

    // The wide layout shows the three-way segmented switcher.
    await tester.tap(find.text('NL'));
    await tester.pumpAndSettle();

    expect(find.text('Elektronisch patiëntendossier'), findsOneWidget);
    expect(find.text('Patiënten'), findsWidgets);

    await tester.tap(find.text('FR'));
    await tester.pumpAndSettle();
    expect(find.text('Dossier patient informatisé'), findsOneWidget);
  });

  testWidgets('a pharmacist cannot write notes or prescribe', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpEhr(tester, role: UserRole.pharmacist);
    await openPatient(tester, 'Van Damme');

    await tester.tap(find.text('Prescriptions'));
    await tester.pumpAndSettle();
    expect(find.text('New prescription'), findsNothing);

    await tester.tap(find.text('Notes and observations'));
    await tester.pumpAndSettle();
    expect(find.text('New note'), findsNothing);
  });

  testWidgets('a physician can open the prescribing dialog', (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpEhr(tester);
    await openPatient(tester, 'Van Damme');

    await tester.tap(find.text('Prescriptions'));
    await tester.pumpAndSettle();
    expect(find.text('New prescription'), findsOneWidget);

    await tester.tap(find.text('New prescription'));
    await tester.pumpAndSettle();
    expect(find.text('Search the formulary'), findsOneWidget);
  });

  testWidgets('the vitals tab draws a chart per measurement', (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await pumpEhr(tester);
    await openPatient(tester, 'Van Damme');

    await tester.tap(find.text('Vital signs'));
    await tester.pumpAndSettle();

    expect(find.byType(VitalTrendChart), findsWidgets);
    expect(find.text('Heart rate'), findsWidgets);
  });
}
