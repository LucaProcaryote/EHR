import 'package:flutter/material.dart';
import 'package:hospital_core/hospital_core.dart';

import 'patient_file_screen.dart';

/// The patient list, and on a wide screen the selected file beside it.
///
/// Master-detail above 1000px, push navigation below: a clinician at the
/// nurses' station keeps the ward list in view while reading a file, and the
/// same code on a phone gives the file the whole screen.
class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _admittedOnly = false;
  String? _selectedPatientId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded = Breakpoints.isExpanded(context);

    final list = _PatientList(
      query: _query,
      admittedOnly: _admittedOnly,
      selectedPatientId: isExpanded ? _selectedPatientId : null,
      searchController: _searchController,
      onQueryChanged: (value) => setState(() => _query = value),
      onAdmittedOnlyChanged: (value) => setState(() => _admittedOnly = value),
      onSelected: (patient) {
        if (isExpanded) {
          setState(() => _selectedPatientId = patient.id);
        } else {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(title: Text(patient.fullName)),
                body: PatientFileScreen(patientId: patient.id),
              ),
            ),
          );
        }
      },
    );

    if (!isExpanded) return list;

    final l10n = HospitalLocalizations.of(context);
    return Row(
      children: <Widget>[
        SizedBox(width: 360, child: list),
        const VerticalDivider(width: 1),
        Expanded(
          child: _selectedPatientId == null
              ? EmptyView(
                  message: l10n.patientSelectPrompt,
                  icon: Icons.folder_shared_outlined,
                )
              : PatientFileScreen(
                  key: ValueKey<String>(_selectedPatientId!),
                  patientId: _selectedPatientId!,
                ),
        ),
      ],
    );
  }
}

class _PatientList extends StatelessWidget {
  const _PatientList({
    required this.query,
    required this.admittedOnly,
    required this.selectedPatientId,
    required this.searchController,
    required this.onQueryChanged,
    required this.onAdmittedOnlyChanged,
    required this.onSelected,
  });

  final String query;
  final bool admittedOnly;
  final String? selectedPatientId;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<bool> onAdmittedOnlyChanged;
  final ValueChanged<Patient> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = HospitalLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            children: <Widget>[
              TextField(
                controller: searchController,
                onChanged: onQueryChanged,
                decoration: InputDecoration(
                  hintText: l10n.patientSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: l10n.actionClear,
                          onPressed: () {
                            searchController.clear();
                            onQueryChanged('');
                          },
                        ),
                ),
              ),
              Gap.h8,
              Align(
                alignment: Alignment.centerLeft,
                child: FilterChip(
                  selected: admittedOnly,
                  onSelected: onAdmittedOnlyChanged,
                  avatar: const Icon(Icons.hotel, size: 16),
                  label: Text(l10n.dashboardAdmittedPatients),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: RepositoryBuilder<_PatientListData>(
            query: (repository) async {
              final patients = await repository.listPatients(query: query);
              final encounters =
                  await repository.listEncounters(activeOnly: true);
              final byPatient = <String, Encounter>{
                for (final encounter in encounters)
                  encounter.patientId: encounter,
              };
              final wards = <String, Ward>{
                for (final ward in await repository.listWards()) ward.id: ward,
              };
              final beds = <String, Bed>{
                for (final bed in await repository.listBeds()) bed.id: bed,
              };
              return _PatientListData(
                patients: admittedOnly
                    ? patients
                        .where((p) => byPatient.containsKey(p.id))
                        .toList(growable: false)
                    : patients,
                encounters: byPatient,
                wards: wards,
                beds: beds,
              );
            },
            builder: (context, data) {
              if (data.patients.isEmpty) {
                return EmptyView(
                  message: l10n.labelNoResults,
                  icon: Icons.person_search_outlined,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.sm,
                  vertical: Gap.sm,
                ),
                itemCount: data.patients.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 2),
                itemBuilder: (context, index) {
                  if (index == data.patients.length) {
                    return Padding(
                      padding: const EdgeInsets.all(Gap.md),
                      child: Text(
                        l10n.patientCount(data.patients.length),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  final patient = data.patients[index];
                  final encounter = data.encounters[patient.id];
                  final bed = encounter?.bedId == null
                      ? null
                      : data.beds[encounter!.bedId];
                  final ward = encounter?.wardId == null
                      ? null
                      : data.wards[encounter!.wardId];

                  return _PatientTile(
                    patient: patient,
                    ward: ward,
                    bed: bed,
                    isSelected: patient.id == selectedPatientId,
                    onTap: () => onSelected(patient),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PatientListData {
  const _PatientListData({
    required this.patients,
    required this.encounters,
    required this.wards,
    required this.beds,
  });

  final List<Patient> patients;
  final Map<String, Encounter> encounters;
  final Map<String, Ward> wards;
  final Map<String, Bed> beds;
}

class _PatientTile extends StatelessWidget {
  const _PatientTile({
    required this.patient,
    required this.ward,
    required this.bed,
    required this.isSelected,
    required this.onTap,
  });

  final Patient patient;
  final Ward? ward;
  final Bed? bed;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = HospitalLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;

    return ListTile(
      selected: isSelected,
      selectedTileColor: theme.colorScheme.secondaryContainer,
      onTap: onTap,
      leading: PatientAvatar(patient: patient, radius: 20),
      title: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              patient.listName,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (patient.hasHighRiskAllergy)
            Tooltip(
              message: l10n.patientHighRiskAllergy,
              child: Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: HospitalTheme.criticalOf(context),
              ),
            ),
        ],
      ),
      subtitle: Text(
        <String>[
          l10n.patientAgeYears(patient.ageAt()),
          patient.mrn,
          if (ward != null && bed != null)
            '${ward!.name.forLanguage(language)} · ${bed!.label}',
        ].join(' · '),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: bed == null
          ? null
          : Icon(Icons.hotel, size: 16, color: theme.colorScheme.primary),
    );
  }
}
