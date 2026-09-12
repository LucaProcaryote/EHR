import 'package:flutter/material.dart';
import 'package:hospital_core/hospital_core.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../widgets/prescription_editor.dart';

/// The patient's medication: what is running now, and what has been stopped.
class PrescriptionsTab extends StatefulWidget {
  const PrescriptionsTab({
    super.key,
    required this.patient,
    required this.encounter,
  });

  final Patient patient;
  final Encounter? encounter;

  @override
  State<PrescriptionsTab> createState() => _PrescriptionsTabState();
}

class _PrescriptionsTabState extends State<PrescriptionsTab> {
  bool _activeOnly = true;

  @override
  Widget build(BuildContext context) {
    final l10n = HospitalLocalizations.of(context);
    final canPrescribe =
        context.watch<AuthService>().currentUser?.role.canPrescribe ?? false;

    return Stack(
      children: <Widget>[
        Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilterChip(
                  selected: _activeOnly,
                  label: Text(l10n.prescriptionActive),
                  onSelected: (value) => setState(() => _activeOnly = value),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: RepositoryBuilder<List<Prescription>>(
                query: (repository) => repository.listPrescriptions(
                  patientId: widget.patient.id,
                  activeOnly: _activeOnly,
                ),
                builder: (context, prescriptions) {
                  if (prescriptions.isEmpty) {
                    return EmptyView(
                      message: l10n.prescriptionNone,
                      icon: Icons.medication_outlined,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.md,
                      Gap.md,
                      Gap.md,
                      88,
                    ),
                    itemCount: prescriptions.length,
                    separatorBuilder: (_, __) => Gap.h8,
                    itemBuilder: (context, index) => _PrescriptionCard(
                      prescription: prescriptions[index],
                      patient: widget.patient,
                      canPrescribe: canPrescribe,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        if (canPrescribe)
          Positioned(
            right: Gap.md,
            bottom: Gap.md,
            child: FloatingActionButton.extended(
              onPressed: _newPrescription,
              icon: const Icon(Icons.add),
              label: Text(l10n.prescriptionNew),
            ),
          ),
      ],
    );
  }

  Future<void> _newPrescription() async {
    final repository = context.read<HospitalRepository>();
    final user = context.read<AuthService>().currentUser;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = HospitalLocalizations.of(context);

    final draft = await showDialog<PrescriptionDraft>(
      context: context,
      builder: (context) => PrescriptionEditorDialog(patient: widget.patient),
    );
    if (draft == null) return;

    await repository.savePrescription(Prescription(
      id: 'rx-${const Uuid().v4()}',
      patientId: widget.patient.id,
      encounterId: widget.encounter?.id,
      medication: draft.medication,
      doseQuantity: draft.doseQuantity,
      doseUnit: draft.doseUnit,
      frequencyPerDay: draft.frequencyPerDay,
      route: draft.route,
      startDate: DateTime.now(),
      prescriber: user?.displayName ?? 'Unknown',
      status: PrescriptionStatus.active,
      isPrn: draft.isPrn,
      indication: draft.indication,
      instructions: draft.instructions,
    ));

    messenger.showSnackBar(
      SnackBar(content: Text(l10n.prescriptionSaved)),
    );
  }
}

class _PrescriptionCard extends StatelessWidget {
  const _PrescriptionCard({
    required this.prescription,
    required this.patient,
    required this.canPrescribe,
  });

  final Prescription prescription;
  final Patient patient;
  final bool canPrescribe;

  Color _statusColor(BuildContext context) => switch (prescription.status) {
        PrescriptionStatus.active => HospitalTheme.successOf(context),
        PrescriptionStatus.onHold => HospitalTheme.warningOf(context),
        PrescriptionStatus.cancelled => HospitalTheme.criticalOf(context),
        _ => Theme.of(context).colorScheme.outline,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = HospitalLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final medication = prescription.medication;

    // Re-run the allergy check on display, not only at prescribing time: an
    // allergy can be recorded after the drug was started, and this is the
    // screen where somebody would notice.
    final alerts = SafetyChecks.allergyAlerts(
      patient: patient,
      medication: medication,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${medication.name.forLanguage(language)} '
                        '${medication.strength}',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        medication.form.forLanguage(language),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip(
                  label: prescription.status.display.forLanguage(language),
                  color: _statusColor(context),
                  dense: true,
                ),
                if (medication.isControlled) ...<Widget>[
                  Gap.w8,
                  StatusChip(
                    label: l10n.medicationControlled,
                    color: HospitalTheme.warningOf(context),
                    icon: Icons.lock_outline,
                    dense: true,
                  ),
                ],
              ],
            ),
            Gap.h8,
            Text(
              prescription.dosageText(language),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            Gap.h8,
            Wrap(
              spacing: Gap.lg,
              runSpacing: Gap.sm,
              children: <Widget>[
                LabeledValue(
                  label: l10n.prescriptionPrescriber,
                  value: prescription.prescriber,
                ),
                LabeledValue(
                  label: l10n.prescriptionStartDate,
                  value: Formats.date(context, prescription.startDate),
                ),
                if (prescription.indication != null)
                  LabeledValue(
                    label: l10n.prescriptionIndication,
                    value: prescription.indication!,
                  ),
                LabeledValue(label: 'ATC', value: medication.atcCode),
              ],
            ),
            if (alerts.isNotEmpty) ...<Widget>[
              Gap.h8,
              for (final alert in alerts)
                _AlertRow(alert: alert, language: language),
            ],
            if (canPrescribe && prescription.isActive) ...<Widget>[
              Gap.h8,
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton.icon(
                    onPressed: () => _changeStatus(
                      context,
                      PrescriptionStatus.onHold,
                    ),
                    icon: const Icon(Icons.pause, size: 16),
                    label: Text(l10n.prescriptionHold),
                  ),
                  Gap.w8,
                  TextButton.icon(
                    onPressed: () => _changeStatus(
                      context,
                      PrescriptionStatus.cancelled,
                    ),
                    icon: const Icon(Icons.stop_circle_outlined, size: 16),
                    label: Text(l10n.prescriptionStop),
                  ),
                ],
              ),
            ],
            if (canPrescribe &&
                prescription.status == PrescriptionStatus.onHold) ...<Widget>[
              Gap.h8,
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () =>
                      _changeStatus(context, PrescriptionStatus.active),
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: Text(l10n.prescriptionResume),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _changeStatus(
    BuildContext context,
    PrescriptionStatus status,
  ) async {
    await context
        .read<HospitalRepository>()
        .savePrescription(prescription.copyWith(status: status));
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert, required this.language});

  final SafetyAlert alert;
  final String language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = alert.severity == SafetySeverity.blocking
        ? HospitalTheme.criticalOf(context)
        : HospitalTheme.warningOf(context);

    return Container(
      margin: const EdgeInsets.only(top: Gap.xs),
      padding: const EdgeInsets.all(Gap.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, size: 16, color: color),
          Gap.w8,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  alert.title.forLanguage(language),
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
                Text(
                  alert.detail.forLanguage(language),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
