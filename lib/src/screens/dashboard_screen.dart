import 'package:flutter/material.dart';
import 'package:hospital_core/hospital_core.dart';

/// A ward-level overview: how many patients are in, and which measurements
/// need a look.
///
/// The abnormal-vitals list is the point of this screen. Counting patients is
/// easy; noticing that bed 221-A desaturated an hour ago is the job.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = HospitalLocalizations.of(context);

    return RepositoryBuilder<_DashboardData>(
      query: (repository) async {
        final encounters = await repository.listEncounters(activeOnly: true);
        final beds = await repository.listBeds();
        final wards = await repository.listWards();
        final patients = <String, Patient>{};
        final abnormal = <_AbnormalReading>[];

        for (final encounter in encounters) {
          final patient = await repository.findPatient(encounter.patientId);
          if (patient == null) continue;
          patients[patient.id] = patient;

          final vitals = await repository.latestVitals(patient.id);
          for (final observation in vitals.values) {
            if (!observation.isAbnormal) continue;
            abnormal.add(
              _AbnormalReading(
                patient: patient,
                observation: observation,
                encounter: encounter,
              ),
            );
          }
        }

        // Worst first is not well defined across different measurements, so
        // sort by recency: the newest abnormal reading is the one a clinician
        // has least likely already seen.
        abnormal.sort(
          (a, b) => b.observation.effectiveDateTime.compareTo(
            a.observation.effectiveDateTime,
          ),
        );

        final notes = await repository.listNotes();

        return _DashboardData(
          encounters: encounters,
          patients: patients,
          beds: beds,
          wards: wards,
          abnormal: abnormal,
          recentNotes: notes.take(8).toList(growable: false),
        );
      },
      builder: (context, data) => ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: <Widget>[
          _StatRow(data: data),
          Gap.h16,
          SectionCard(
            title: l10n.dashboardAbnormalVitals,
            icon: Icons.monitor_heart_outlined,
            padding: EdgeInsets.zero,
            trailing: Padding(
              padding: const EdgeInsets.only(right: Gap.sm),
              child: Text(
                '${data.abnormal.length}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            child: data.abnormal.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(Gap.md),
                    child: Text(l10n.safetyNoIssues),
                  )
                : Column(
                    children: <Widget>[
                      for (final reading in data.abnormal.take(15))
                        _AbnormalRow(reading: reading, data: data),
                    ],
                  ),
          ),
          Gap.h16,
          SectionCard(
            title: l10n.dashboardRecentActivity,
            icon: Icons.history,
            padding: EdgeInsets.zero,
            child: data.recentNotes.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(Gap.md),
                    child: Text(l10n.noteNone),
                  )
                : Column(
                    children: <Widget>[
                      for (final note in data.recentNotes)
                        ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.note_alt_outlined,
                            size: 18,
                          ),
                          title: Text(note.title),
                          subtitle: Text(
                            '${data.patients[note.patientId]?.fullName ?? note.patientId}'
                            ' · ${note.authorName}',
                          ),
                          trailing: Text(
                            Formats.smart(context, note.createdAt),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _DashboardData {
  const _DashboardData({
    required this.encounters,
    required this.patients,
    required this.beds,
    required this.wards,
    required this.abnormal,
    required this.recentNotes,
  });

  final List<Encounter> encounters;
  final Map<String, Patient> patients;
  final List<Bed> beds;
  final List<Ward> wards;
  final List<_AbnormalReading> abnormal;
  final List<ClinicalNote> recentNotes;
}

class _AbnormalReading {
  const _AbnormalReading({
    required this.patient,
    required this.observation,
    required this.encounter,
  });

  final Patient patient;
  final Observation observation;
  final Encounter encounter;
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.data});

  final _DashboardData data;

  @override
  Widget build(BuildContext context) {
    final l10n = HospitalLocalizations.of(context);
    final freeBeds = data.beds.where((b) => b.isAvailable).length;
    final occupancy = data.beds.isEmpty
        ? 0.0
        : data.beds.where((b) => b.status == BedStatus.occupied).length /
              data.beds.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 220).floor().clamp(1, 4);
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Gap.md,
          crossAxisSpacing: Gap.md,
          childAspectRatio: 1.9,
          children: <Widget>[
            _StatTile(
              label: l10n.dashboardAdmittedPatients,
              value: '${data.encounters.length}',
              icon: Icons.people,
            ),
            _StatTile(
              label: l10n.dashboardFreeBeds,
              value: '$freeBeds',
              icon: Icons.hotel,
            ),
            _StatTile(
              label: l10n.adtOccupancy,
              value: '${(occupancy * 100).round()}%',
              icon: Icons.pie_chart_outline,
            ),
            _StatTile(
              label: l10n.dashboardAbnormalVitals,
              value: '${data.abnormal.length}',
              icon: Icons.warning_amber_rounded,
              emphasise: data.abnormal.isNotEmpty,
            ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    this.emphasise = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = emphasise
        ? HospitalTheme.criticalOf(context)
        : theme.colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 18, color: color),
                Gap.w8,
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Gap.h8,
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AbnormalRow extends StatelessWidget {
  const _AbnormalRow({required this.reading, required this.data});

  final _AbnormalReading reading;
  final _DashboardData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final observation = reading.observation;
    final color = HospitalTheme.criticalOf(context);
    final bed = data.beds
        .where((b) => b.id == reading.encounter.bedId)
        .firstOrNull;

    return ListTile(
      dense: true,
      leading: PatientAvatar(patient: reading.patient, radius: 16),
      title: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              reading.patient.fullName,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Value, unit and the word "high"/"low" - never colour on its own.
          StatusChip(
            label:
                '${observation.formatted} · '
                '${observation.interpretationCode == 'H' ? '↑' : '↓'}',
            color: color,
            dense: true,
          ),
        ],
      ),
      subtitle: Text(
        '${observation.type.display.forLanguage(language)}'
        '${bed == null ? '' : ' · ${bed.label}'}'
        ' · ${Formats.ago(context, observation.effectiveDateTime)}',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
