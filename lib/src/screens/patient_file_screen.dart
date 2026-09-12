import 'package:flutter/material.dart';
import 'package:hospital_core/hospital_core.dart';

import 'tabs/notes_tab.dart';
import 'tabs/overview_tab.dart';
import 'tabs/prescriptions_tab.dart';
import 'tabs/vitals_tab.dart';

/// The patient fiche: who the patient is, where they are, and everything
/// recorded about the current stay.
///
/// The identity strip and the allergy banner stay pinned above the tabs. A
/// clinician must never have to remember which patient a tab belongs to, and
/// an allergy that is one tab away is an allergy that gets missed.
class PatientFileScreen extends StatelessWidget {
  const PatientFileScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) {
    final l10n = HospitalLocalizations.of(context);

    return RepositoryBuilder<_PatientFileData?>(
      query: (repository) async {
        final patient = await repository.findPatient(patientId);
        if (patient == null) return null;
        final encounter = await repository.activeEncounterFor(patientId);
        BedPlacement? placement;
        if (encounter?.bedId != null) {
          placement = await repository.resolvePlacement(encounter!.bedId!);
        }
        return _PatientFileData(
          patient: patient,
          encounter: encounter,
          placement: placement,
        );
      },
      builder: (context, data) {
        if (data == null) {
          return EmptyView(
            message: l10n.patientNotFound,
            icon: Icons.person_off_outlined,
          );
        }
        return _PatientFileBody(data: data);
      },
    );
  }
}

class _PatientFileData {
  const _PatientFileData({
    required this.patient,
    required this.encounter,
    required this.placement,
  });

  final Patient patient;
  final Encounter? encounter;
  final BedPlacement? placement;
}

class _PatientFileBody extends StatelessWidget {
  const _PatientFileBody({required this.data});

  final _PatientFileData data;

  @override
  Widget build(BuildContext context) {
    final l10n = HospitalLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final patient = data.patient;
    final encounter = data.encounter;

    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                PatientIdentityBar(
                  patient: patient,
                  trailing: encounter == null
                      ? StatusChip(
                          label: l10n.encounterNone,
                          color: theme.colorScheme.outline,
                        )
                      : StatusChip(
                          label: data.placement == null
                              ? encounter.encounterClass.display
                                  .forLanguage(language)
                              : data.placement!.describe(language),
                          color: HospitalTheme.infoOf(context),
                          icon: Icons.hotel,
                        ),
                ),
                Gap.h16,
                AllergyBanner(patient: patient),
              ],
            ),
          ),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: <Widget>[
              Tab(text: l10n.navOverview),
              Tab(text: l10n.vitals),
              Tab(text: l10n.prescriptions),
              Tab(text: l10n.notesTitle),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                OverviewTab(patient: patient, encounter: encounter),
                VitalsTab(patient: patient),
                PrescriptionsTab(patient: patient, encounter: encounter),
                NotesTab(patient: patient, encounter: encounter),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
