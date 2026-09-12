import 'package:flutter/material.dart';
import 'package:hospital_core/hospital_core.dart';

/// Administrative and clinical summary: who the patient is, where they are,
/// and their most recent measurements at a glance.
class OverviewTab extends StatelessWidget {
  const OverviewTab({
    super.key,
    required this.patient,
    required this.encounter,
  });

  final Patient patient;
  final Encounter? encounter;

  @override
  Widget build(BuildContext context) {
    final l10n = HospitalLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;

    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: <Widget>[
        SectionCard(
          title: l10n.patientDemographics,
          icon: Icons.badge_outlined,
          child: Wrap(
            spacing: Gap.lg,
            runSpacing: Gap.md,
            children: <Widget>[
              LabeledValue(
                label: l10n.patientMrn,
                value: patient.mrn,
                monospace: true,
              ),
              LabeledValue(
                label: l10n.patientNationalNumber,
                value: patient.nationalNumber ?? '',
                monospace: true,
              ),
              LabeledValue(
                label: l10n.patientDateOfBirth,
                value:
                    '${Formats.date(context, patient.birthDate)} '
                    '(${l10n.patientAgeYears(patient.ageAt())})',
              ),
              LabeledValue(
                label: l10n.patientGender,
                value: patient.gender.display.forLanguage(language),
              ),
              LabeledValue(
                label: l10n.patientBloodGroup,
                value: patient.bloodGroup ?? '',
              ),
              LabeledValue(
                label: l10n.patientPreferredLanguage,
                value:
                    SupportedLocales.nativeNames[patient.preferredLanguage] ??
                    patient.preferredLanguage,
              ),
              LabeledValue(
                label: l10n.patientAddress,
                value: patient.address.oneLine,
              ),
              LabeledValue(
                label: l10n.patientPhone,
                value: patient.phone ?? '',
              ),
              LabeledValue(
                label: l10n.patientEmail,
                value: patient.email ?? '',
              ),
              LabeledValue(
                label: l10n.patientGeneralPractitioner,
                value: patient.generalPractitioner ?? '',
              ),
            ],
          ),
        ),
        Gap.h16,
        _EncounterCard(patient: patient, encounter: encounter),
        Gap.h16,
        _LatestVitalsCard(patient: patient),
      ],
    );
  }
}

class _EncounterCard extends StatelessWidget {
  const _EncounterCard({required this.patient, required this.encounter});

  final Patient patient;
  final Encounter? encounter;

  @override
  Widget build(BuildContext context) {
    final l10n = HospitalLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final current = encounter;

    if (current == null) {
      return SectionCard(
        title: l10n.encounterActive,
        icon: Icons.hotel_outlined,
        child: Text(l10n.encounterNone),
      );
    }

    return RepositoryBuilder<
      ({BedPlacement? placement, List<Movement> movements})
    >(
      query: (repository) async => (
        placement: current.bedId == null
            ? null
            : await repository.resolvePlacement(current.bedId!),
        movements: await repository.listMovements(encounterId: current.id),
      ),
      builder: (context, data) => SectionCard(
        title: l10n.encounterActive,
        icon: Icons.hotel_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: Gap.lg,
              runSpacing: Gap.md,
              children: <Widget>[
                LabeledValue(
                  label: l10n.encounterVisitNumber,
                  value: current.visitNumber ?? '',
                  monospace: true,
                ),
                LabeledValue(
                  label: l10n.adtEncounterClass,
                  value: current.encounterClass.display.forLanguage(language),
                ),
                LabeledValue(
                  label: l10n.encounterAdmittedOn,
                  value: Formats.dateTime(context, current.admissionDate),
                ),
                LabeledValue(
                  label: l10n.encounterLengthOfStay,
                  value: l10n.encounterDays(current.lengthOfStayDays),
                ),
                LabeledValue(
                  label: l10n.locationBed,
                  value:
                      data.placement?.describe(language) ??
                      l10n.locationNotPlaced,
                ),
                LabeledValue(
                  label: l10n.encounterAttending,
                  value: current.attendingPractitioner ?? '',
                ),
                LabeledValue(
                  label: l10n.encounterReason,
                  value: current.reason ?? '',
                ),
              ],
            ),
            if (data.movements.isNotEmpty) ...<Widget>[
              const Divider(height: Gap.lg),
              Text(
                l10n.adtMovementHistory,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              Gap.h8,
              for (final movement in data.movements)
                _MovementRow(movement: movement),
            ],
          ],
        ),
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement});

  final Movement movement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final icon = switch (movement.type) {
      MovementType.admission => Icons.login,
      MovementType.discharge => Icons.logout,
      MovementType.transfer => Icons.swap_horiz,
      _ => Icons.circle_outlined,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          Gap.w8,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${movement.type.display.forLanguage(language)} '
                  '(${movement.type.hl7EventCode})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (movement.note != null)
                  Text(
                    movement.note!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            Formats.smart(context, movement.occurredAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _LatestVitalsCard extends StatelessWidget {
  const _LatestVitalsCard({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final l10n = HospitalLocalizations.of(context);

    return RepositoryBuilder<Map<VitalSignType, Observation>>(
      query: (repository) => repository.latestVitals(patient.id),
      builder: (context, vitals) {
        if (vitals.isEmpty) {
          return SectionCard(
            title: l10n.vitalsLatest,
            icon: Icons.monitor_heart_outlined,
            child: Text(l10n.vitalsNone),
          );
        }
        final ordered = VitalSignType.values
            .where(vitals.containsKey)
            .toList(growable: false);
        return SectionCard(
          title: l10n.vitalsLatest,
          icon: Icons.monitor_heart_outlined,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Aim for tiles around 170px wide, at least two per row.
              final columns = (constraints.maxWidth / 180).floor().clamp(2, 5);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: Gap.sm,
                  crossAxisSpacing: Gap.sm,
                  childAspectRatio: 1.25,
                ),
                itemCount: ordered.length,
                itemBuilder: (context, index) => VitalTile(
                  type: ordered[index],
                  latest: vitals[ordered[index]],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
