import 'package:flutter/material.dart';
import 'package:hospital_core/hospital_core.dart';

/// The measurement history, one chart per vital sign.
///
/// The window selector is the only control: everything else follows from the
/// data. Vitals are never overlaid on a shared axis - see [VitalTrendChart].
class VitalsTab extends StatefulWidget {
  const VitalsTab({super.key, required this.patient});

  final Patient patient;

  @override
  State<VitalsTab> createState() => _VitalsTabState();
}

enum _Window { last24h, last72h, all }

class _VitalsTabState extends State<VitalsTab> {
  _Window _window = _Window.last72h;

  DateTime? get _since => switch (_window) {
    _Window.last24h => DateTime.now().subtract(const Duration(hours: 24)),
    _Window.last72h => DateTime.now().subtract(const Duration(hours: 72)),
    _Window.all => null,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = HospitalLocalizations.of(context);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<_Window>(
              showSelectedIcon: false,
              segments: <ButtonSegment<_Window>>[
                ButtonSegment<_Window>(
                  value: _Window.last24h,
                  label: Text(l10n.vitalsLast24h),
                ),
                ButtonSegment<_Window>(
                  value: _Window.last72h,
                  label: Text(l10n.vitalsLast72h),
                ),
                ButtonSegment<_Window>(
                  value: _Window.all,
                  label: Text(l10n.vitalsAllTime),
                ),
              ],
              selected: <_Window>{_window},
              onSelectionChanged: (value) =>
                  setState(() => _window = value.first),
            ),
          ),
        ),
        Expanded(
          child: RepositoryBuilder<List<Observation>>(
            query: (repository) => repository.listObservations(
              patientId: widget.patient.id,
              since: _since,
              limit: 2000,
            ),
            builder: (context, observations) {
              if (observations.isEmpty) {
                return EmptyView(
                  message: l10n.vitalsNone,
                  icon: Icons.monitor_heart_outlined,
                );
              }

              // Group by measurement, keeping the enum's clinical ordering
              // rather than whatever order the rows happened to arrive in.
              final byType = <VitalSignType, List<Observation>>{};
              for (final observation in observations) {
                byType
                    .putIfAbsent(observation.type, () => <Observation>[])
                    .add(observation);
              }
              final types = VitalSignType.values
                  .where(byType.containsKey)
                  .toList(growable: false);

              return LayoutBuilder(
                builder: (context, constraints) {
                  final columns = (constraints.maxWidth / 420).floor().clamp(
                    1,
                    3,
                  );
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.md,
                      0,
                      Gap.md,
                      Gap.md,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: Gap.md,
                      crossAxisSpacing: Gap.md,
                      mainAxisExtent: 300,
                    ),
                    itemCount: types.length,
                    itemBuilder: (context, index) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(Gap.md),
                        child: VitalTrendChart(
                          type: types[index],
                          observations: byType[types[index]]!,
                        ),
                      ),
                    ),
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
