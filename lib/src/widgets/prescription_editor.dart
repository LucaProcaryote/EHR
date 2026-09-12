import 'package:flutter/material.dart';
import 'package:hospital_core/hospital_core.dart';

/// What the prescribing dialog hands back.
class PrescriptionDraft {
  const PrescriptionDraft({
    required this.medication,
    required this.doseQuantity,
    required this.doseUnit,
    required this.frequencyPerDay,
    required this.route,
    required this.isPrn,
    this.indication,
    this.instructions,
  });

  final Medication medication;
  final double doseQuantity;
  final String doseUnit;
  final int frequencyPerDay;
  final MedicationRoute route;
  final bool isPrn;
  final String? indication;
  final String? instructions;
}

/// Writes a new prescription, running the safety checks as the drug is chosen
/// rather than only when Save is pressed.
///
/// A high-risk allergy blocks the Save button outright; a low-risk one requires
/// an explicit acknowledgement. Neither can be dismissed by scrolling past it.
class PrescriptionEditorDialog extends StatefulWidget {
  const PrescriptionEditorDialog({super.key, required this.patient});

  final Patient patient;

  @override
  State<PrescriptionEditorDialog> createState() =>
      _PrescriptionEditorDialogState();
}

class _PrescriptionEditorDialogState extends State<PrescriptionEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _doseController = TextEditingController(text: '1');
  final _unitController = TextEditingController(text: 'tablet');
  final _indicationController = TextEditingController();
  final _instructionsController = TextEditingController();

  Medication? _medication;
  int _frequency = 3;
  MedicationRoute _route = MedicationRoute.oral;
  bool _isPrn = false;
  bool _acknowledged = false;
  String _query = '';

  List<SafetyAlert> _alerts = const <SafetyAlert>[];

  @override
  void dispose() {
    _searchController.dispose();
    _doseController.dispose();
    _unitController.dispose();
    _indicationController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _selectMedication(Medication medication) {
    setState(() {
      _medication = medication;
      _acknowledged = false;
      _alerts = SafetyChecks.allergyAlerts(
        patient: widget.patient,
        medication: medication,
      );
      // Pre-fill a sensible unit and route from the galenic form.
      final form = medication.form.en.toLowerCase();
      if (form.contains('tablet')) {
        _unitController.text = 'tablet';
        _route = MedicationRoute.oral;
      } else if (form.contains('capsule')) {
        _unitController.text = 'capsule';
        _route = MedicationRoute.oral;
      } else if (form.contains('injection')) {
        _unitController.text = 'mg';
        _route = MedicationRoute.intravenous;
      } else if (form.contains('inhal')) {
        _unitController.text = 'dose';
        _route = MedicationRoute.inhalation;
      } else if (form.contains('syringe')) {
        _unitController.text = 'IU';
        _route = MedicationRoute.subcutaneous;
      } else if (form.contains('infusion')) {
        _unitController.text = 'mL';
        _route = MedicationRoute.intravenous;
      }
    });
  }

  bool get _hasBlockingAlert => _alerts.any((a) => a.isBlocking);
  bool get _needsAcknowledgement =>
      _alerts.any((a) => a.severity == SafetySeverity.warning);

  bool get _canSave {
    if (_medication == null) return false;
    if (_hasBlockingAlert) return false;
    if (_needsAcknowledgement && !_acknowledged) return false;
    return true;
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final medication = _medication;
    if (medication == null || !_canSave) return;

    Navigator.of(context).pop(
      PrescriptionDraft(
        medication: medication,
        doseQuantity:
            double.tryParse(_doseController.text.replaceAll(',', '.')) ?? 1,
        doseUnit: _unitController.text.trim(),
        frequencyPerDay: _frequency,
        route: _route,
        isPrn: _isPrn,
        indication: _indicationController.text.trim().isEmpty
            ? null
            : _indicationController.text.trim(),
        instructions: _instructionsController.text.trim().isEmpty
            ? null
            : _instructionsController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = HospitalLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;

    return AlertDialog(
      title: Text(l10n.prescriptionNew),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AllergyBanner(patient: widget.patient),
                Gap.h16,

                if (_medication == null) ...<Widget>[
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: l10n.formularySearchHint,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  Gap.h8,
                  SizedBox(
                    height: 280,
                    child: RepositoryBuilder<List<Medication>>(
                      query: (repository) =>
                          repository.listFormulary(query: _query),
                      builder: (context, medications) => ListView.builder(
                        itemCount: medications.length,
                        itemBuilder: (context, index) {
                          final medication = medications[index];
                          return ListTile(
                            dense: true,
                            title: Text(
                              '${medication.name.forLanguage(language)} '
                              '${medication.strength}',
                            ),
                            subtitle: Text(
                              '${medication.form.forLanguage(language)} · '
                              '${medication.atcCode}',
                            ),
                            trailing: medication.isControlled
                                ? Icon(
                                    Icons.lock_outline,
                                    size: 16,
                                    color: HospitalTheme.warningOf(context),
                                  )
                                : null,
                            onTap: () => _selectMedication(medication),
                          );
                        },
                      ),
                    ),
                  ),
                ] else ...<Widget>[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${_medication!.name.forLanguage(language)} '
                      '${_medication!.strength}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(_medication!.form.forLanguage(language)),
                    trailing: TextButton(
                      onPressed: () => setState(() {
                        _medication = null;
                        _alerts = const <SafetyAlert>[];
                        _acknowledged = false;
                      }),
                      child: Text(l10n.actionEdit),
                    ),
                  ),

                  if (_alerts.isNotEmpty) ...<Widget>[
                    Gap.h8,
                    Text(l10n.safetyChecks, style: theme.textTheme.labelLarge),
                    for (final alert in _alerts)
                      _AlertBox(alert: alert, language: language),
                    if (_hasBlockingAlert)
                      Padding(
                        padding: const EdgeInsets.only(top: Gap.sm),
                        child: Text(
                          l10n.safetyBlocked,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: HospitalTheme.criticalOf(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else if (_needsAcknowledgement)
                      CheckboxListTile(
                        value: _acknowledged,
                        onChanged: (value) =>
                            setState(() => _acknowledged = value ?? false),
                        title: Text(
                          l10n.safetyAcknowledge,
                          style: theme.textTheme.bodySmall,
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],

                  Gap.h16,
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: _doseController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.prescriptionDose,
                          ),
                          validator: (value) {
                            final parsed = double.tryParse(
                              (value ?? '').replaceAll(',', '.'),
                            );
                            if (parsed == null || parsed <= 0) {
                              return l10n.errorInvalidNumber;
                            }
                            return null;
                          },
                        ),
                      ),
                      Gap.w16,
                      Expanded(
                        child: TextFormField(
                          controller: _unitController,
                          decoration: const InputDecoration(labelText: 'Unit'),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? l10n.errorFieldRequired
                              : null,
                        ),
                      ),
                    ],
                  ),
                  Gap.h16,
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _frequency,
                          decoration: InputDecoration(
                            labelText: l10n.prescriptionFrequency,
                          ),
                          items: <DropdownMenuItem<int>>[
                            for (final frequency in <int>[1, 2, 3, 4, 6])
                              DropdownMenuItem<int>(
                                value: frequency,
                                child: Text(
                                  l10n.prescriptionTimesPerDay(frequency),
                                ),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _frequency = value ?? _frequency),
                        ),
                      ),
                      Gap.w16,
                      Expanded(
                        child: DropdownButtonFormField<MedicationRoute>(
                          initialValue: _route,
                          decoration: InputDecoration(
                            labelText: l10n.prescriptionRoute,
                          ),
                          items: <DropdownMenuItem<MedicationRoute>>[
                            for (final route in MedicationRoute.values)
                              DropdownMenuItem<MedicationRoute>(
                                value: route,
                                child: Text(
                                  route.display.forLanguage(language),
                                ),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _route = value ?? _route),
                        ),
                      ),
                    ],
                  ),
                  Gap.h8,
                  CheckboxListTile(
                    value: _isPrn,
                    onChanged: (value) =>
                        setState(() => _isPrn = value ?? false),
                    title: Text(l10n.prescriptionAsNeeded),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  TextFormField(
                    controller: _indicationController,
                    decoration: InputDecoration(
                      labelText:
                          '${l10n.prescriptionIndication} (${l10n.labelOptional})',
                    ),
                  ),
                  Gap.h16,
                  TextFormField(
                    controller: _instructionsController,
                    decoration: InputDecoration(
                      labelText:
                          '${l10n.prescriptionInstructions} (${l10n.labelOptional})',
                    ),
                    minLines: 2,
                    maxLines: 4,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: _canSave ? _save : null,
          child: Text(l10n.actionSave),
        ),
      ],
    );
  }
}

class _AlertBox extends StatelessWidget {
  const _AlertBox({required this.alert, required this.language});

  final SafetyAlert alert;
  final String language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (alert.severity) {
      SafetySeverity.blocking => HospitalTheme.criticalOf(context),
      SafetySeverity.warning => HospitalTheme.warningOf(context),
      SafetySeverity.advisory => HospitalTheme.infoOf(context),
    };
    final l10n = HospitalLocalizations.of(context);
    final severityLabel = switch (alert.severity) {
      SafetySeverity.blocking => l10n.safetySeverityBlocking,
      SafetySeverity.warning => l10n.safetySeverityWarning,
      SafetySeverity.advisory => l10n.safetySeverityAdvisory,
    };

    return Container(
      margin: const EdgeInsets.only(top: Gap.sm),
      padding: const EdgeInsets.all(Gap.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, size: 18, color: color),
          Gap.w8,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        alert.title.forLanguage(language),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    // The severity is written, not only coloured.
                    Text(
                      severityLabel,
                      style: theme.textTheme.labelSmall?.copyWith(color: color),
                    ),
                  ],
                ),
                Text(
                  alert.detail.forLanguage(language),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
