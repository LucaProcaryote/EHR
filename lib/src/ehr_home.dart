import 'package:flutter/material.dart';
import 'package:hospital_core/hospital_core.dart';

import 'screens/dashboard_screen.dart';
import 'screens/patients_screen.dart';

/// The Electronic Health Record's top-level navigation.
class EhrHome extends StatelessWidget {
  const EhrHome({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = HospitalLocalizations.of(context);
    return AppShell(
      title: l10n.appTitleEhr,
      // Patients first: the record exists to be read, and a clinician opening
      // this application almost always wants a specific person.
      initialIndex: 0,
      destinations: <ShellDestination>[
        ShellDestination(
          label: (l10n) => l10n.navPatients,
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          builder: (context) => const PatientsScreen(),
        ),
        ShellDestination(
          label: (l10n) => l10n.navDashboard,
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          builder: (context) => const DashboardScreen(),
        ),
      ],
    );
  }
}
