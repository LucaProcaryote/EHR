import 'package:flutter/material.dart';
import 'package:hospital_core/hospital_core.dart';

import 'src/ehr_home.dart';

/// Entry point of the Electronic Health Record.
///
/// Everything configurable is a `--dart-define`, so one build runs against the
/// in-memory dataset, the local PostgreSQL API or Firebase:
///
/// ```
/// flutter run -d chrome                                  # demo data
/// flutter run -d chrome --dart-define=BACKEND=restApi    # local API + Postgres
/// flutter run -d chrome --dart-define=AUTH=firebase      # real sign-in
/// ```
void main() {
  runApp(
    MiniHospitalApp(
      config: AppConfig.fromEnvironment(HospitalApp.ehr),
      title: (l10n) => l10n.appTitleEhr,
      subtitle: (l10n) => l10n.hospitalName,
      homeBuilder: (context) => const EhrHome(),
    ),
  );
}
