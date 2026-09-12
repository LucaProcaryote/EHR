import 'package:flutter/material.dart';
import 'package:hospital_core/hospital_core.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

/// Clinical notes and observations.
///
/// Notes are shown in the language they were written in, labelled with that
/// language, and never machine-translated: a French discharge summary read as
/// approximate Dutch is a clinical risk, not a feature.
class NotesTab extends StatefulWidget {
  const NotesTab({super.key, required this.patient, required this.encounter});

  final Patient patient;
  final Encounter? encounter;

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  NoteType? _filter;

  @override
  Widget build(BuildContext context) {
    final l10n = HospitalLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final canWrite =
        context.watch<AuthService>().currentUser?.role.canWriteNotes ?? false;

    return Stack(
      children: <Widget>[
        Column(
          children: <Widget>[
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                    child: FilterChip(
                      selected: _filter == null,
                      label: Text(l10n.labelAll),
                      onSelected: (_) => setState(() => _filter = null),
                    ),
                  ),
                  for (final type in NoteType.values)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: Gap.sm,
                        top: Gap.sm,
                        bottom: Gap.sm,
                      ),
                      child: FilterChip(
                        selected: _filter == type,
                        label: Text(type.display.forLanguage(language)),
                        onSelected: (_) => setState(() => _filter = type),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: RepositoryBuilder<List<ClinicalNote>>(
                query: (repository) => repository.listNotes(
                  patientId: widget.patient.id,
                  type: _filter,
                ),
                builder: (context, notes) {
                  if (notes.isEmpty) {
                    return EmptyView(
                      message: l10n.noteNone,
                      icon: Icons.note_alt_outlined,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.md,
                      Gap.md,
                      Gap.md,
                      88,
                    ),
                    itemCount: notes.length,
                    separatorBuilder: (_, __) => Gap.h8,
                    itemBuilder: (context, index) => _NoteCard(
                      note: notes[index],
                      canWrite: canWrite,
                      onEdit: () => _openEditor(existing: notes[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        if (canWrite)
          Positioned(
            right: Gap.md,
            bottom: Gap.md,
            child: FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: Text(l10n.noteNew),
            ),
          ),
      ],
    );
  }

  Future<void> _openEditor({ClinicalNote? existing}) async {
    final repository = context.read<HospitalRepository>();
    final user = context.read<AuthService>().currentUser;
    final language = Localizations.localeOf(context).languageCode;

    final result = await showDialog<ClinicalNote>(
      context: context,
      builder: (context) => _NoteEditorDialog(
        existing: existing,
        patientId: widget.patient.id,
        encounterId: widget.encounter?.id,
        authorName: user?.displayName ?? 'Unknown',
        authorRole: user?.role.name ?? 'student',
        language: language,
      ),
    );
    if (result != null) await repository.saveNote(result);
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.canWrite,
    required this.onEdit,
  });

  final ClinicalNote note;
  final bool canWrite;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = HospitalLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final interfaceLanguage = language;
    final isForeign = note.language != interfaceLanguage;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    note.title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                StatusChip(
                  label: note.type.display.forLanguage(language),
                  color: theme.colorScheme.primary,
                  dense: true,
                ),
                if (!note.isSigned) ...<Widget>[
                  Gap.w8,
                  StatusChip(
                    label: l10n.noteUnsigned,
                    color: HospitalTheme.warningOf(context),
                    dense: true,
                  ),
                ],
                if (canWrite && !note.isSigned)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: l10n.actionEdit,
                    onPressed: onEdit,
                  ),
              ],
            ),
            Gap.h4,
            Row(
              children: <Widget>[
                Text(
                  '${note.authorName} · ${Formats.dateTime(context, note.createdAt)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isForeign) ...<Widget>[
                  Gap.w8,
                  // The note is not in the language the user chose. Say so
                  // rather than quietly showing text they may misread.
                  Tooltip(
                    message: l10n.noteWrittenIn(
                      SupportedLocales.nativeNames[note.language] ??
                          note.language,
                    ),
                    child: StatusChip(
                      label: SupportedLocales.shortNames[note.language] ??
                          note.language.toUpperCase(),
                      color: theme.colorScheme.tertiary,
                      icon: Icons.translate,
                      dense: true,
                    ),
                  ),
                ],
              ],
            ),
            Gap.h8,
            SelectableText(
              note.body,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteEditorDialog extends StatefulWidget {
  const _NoteEditorDialog({
    required this.existing,
    required this.patientId,
    required this.encounterId,
    required this.authorName,
    required this.authorRole,
    required this.language,
  });

  final ClinicalNote? existing;
  final String patientId;
  final String? encounterId;
  final String authorName;
  final String authorRole;
  final String language;

  @override
  State<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<_NoteEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _bodyController =
      TextEditingController(text: widget.existing?.body ?? '');
  late NoteType _type = widget.existing?.type ?? NoteType.progress;
  late String _language = widget.existing?.language ?? widget.language;
  bool _sign = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final now = DateTime.now();
    final existing = widget.existing;
    final note = existing == null
        ? ClinicalNote(
            id: 'note-${const Uuid().v4()}',
            patientId: widget.patientId,
            encounterId: widget.encounterId,
            type: _type,
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
            authorName: widget.authorName,
            authorRole: widget.authorRole,
            createdAt: now,
            isSigned: _sign,
            language: _language,
          )
        : existing.copyWith(
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
            type: _type,
            isSigned: _sign || existing.isSigned,
            updatedAt: now,
          );
    Navigator.of(context).pop(note);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = HospitalLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;

    return AlertDialog(
      title: Text(widget.existing == null ? l10n.noteNew : l10n.actionEdit),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<NoteType>(
                        initialValue: _type,
                        decoration: InputDecoration(labelText: l10n.noteType),
                        items: <DropdownMenuItem<NoteType>>[
                          for (final type in NoteType.values)
                            DropdownMenuItem<NoteType>(
                              value: type,
                              child: Text(type.display.forLanguage(language)),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _type = value ?? _type),
                      ),
                    ),
                    Gap.w16,
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _language,
                        decoration:
                            InputDecoration(labelText: l10n.labelLanguage),
                        items: <DropdownMenuItem<String>>[
                          for (final locale in SupportedLocales.all)
                            DropdownMenuItem<String>(
                              value: locale.languageCode,
                              child: Text(
                                SupportedLocales.nativeNameOf(locale),
                              ),
                            ),
                        ],
                        onChanged: widget.existing != null
                            ? null
                            : (value) =>
                                setState(() => _language = value ?? _language),
                      ),
                    ),
                  ],
                ),
                Gap.h16,
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: l10n.noteTitleField),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? l10n.errorFieldRequired
                      : null,
                ),
                Gap.h16,
                TextFormField(
                  controller: _bodyController,
                  decoration: InputDecoration(
                    labelText: l10n.noteBody,
                    alignLabelWithHint: true,
                  ),
                  minLines: 8,
                  maxLines: 16,
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? l10n.errorFieldRequired
                      : null,
                ),
                Gap.h8,
                CheckboxListTile(
                  value: _sign,
                  onChanged: (value) => setState(() => _sign = value ?? false),
                  title: Text(l10n.actionSign),
                  subtitle: Text(
                    l10n.noteSignConfirm,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
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
        FilledButton(onPressed: _save, child: Text(l10n.actionSave)),
      ],
    );
  }
}
