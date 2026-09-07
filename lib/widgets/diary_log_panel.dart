import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/diary_entry.dart';
import '../services/diary_print_service.dart';
import '../services/diary_service.dart';
import '../services/user_service.dart';

class DiaryLogPanel extends StatefulWidget {
  const DiaryLogPanel({
    super.key,
    required this.facilityId,
    required this.facilityName,
    this.compact = false,
  });

  final String facilityId;
  final String facilityName;
  final bool compact;

  @override
  State<DiaryLogPanel> createState() => _DiaryLogPanelState();
}

class _DiaryLogPanelState extends State<DiaryLogPanel> {
  final TextEditingController _searchController = TextEditingController();
  late Future<String> _roleFuture;
  late Stream<List<DiaryEntry>> _entriesStream;
  Timer? _initialLoadTimer;
  DiaryPeriod _period = DiaryPeriod.day;
  DateTime _focusDate = DateTime.now();
  String _category = 'Alle kategorier';
  bool _busy = false;
  bool _waitingForFirstEntries = true;
  bool _initialLoadTimedOut = false;

  @override
  void initState() {
    super.initState();
    _roleFuture = UserService.getCurrentUserRole();
    _configureEntriesStream();
  }

  @override
  void didUpdateWidget(covariant DiaryLogPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.facilityId != widget.facilityId) {
      _configureEntriesStream();
    }
  }

  @override
  void dispose() {
    _initialLoadTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(widget.compact ? 16 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFDCE4EE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF102A43).withValues(alpha: 0.045),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FutureBuilder<String>(
        future: _roleFuture,
        builder: (context, roleSnapshot) {
          final role = roleSnapshot.data ?? 'leser';
          final canCreate = role == 'admin' || role == 'ansatt';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(canCreate: canCreate),
              const SizedBox(height: 18),
              _periodControl(),
              const SizedBox(height: 14),
              _navigationRow(),
              const SizedBox(height: 14),
              _filterRow(),
              const SizedBox(height: 14),
              StreamBuilder<List<DiaryEntry>>(
                stream: _entriesStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    _finishInitialLoad();
                    return _errorState(snapshot.error);
                  }
                  if (!snapshot.hasData) {
                    if (_initialLoadTimedOut) {
                      return _timeoutState();
                    }
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  _finishInitialLoad();

                  final entries = _filterEntries(snapshot.data!);
                  if (entries.isEmpty) return _emptyState();

                  final visibleEntries =
                      widget.compact ? entries.take(5).toList() : entries;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entries.length} innlegg i visningen',
                        style: const TextStyle(
                          color: Color(0xFF61718A),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...visibleEntries.map(
                        (entry) => _DiaryEntryCard(
                          entry: entry,
                          canEdit: _canEdit(role, entry),
                          canArchive: role == 'admin',
                          onEdit: () => _editEntry(entry),
                          onArchive: () => _archiveEntry(entry),
                          onPrint: () => _printEntry(entry),
                        ),
                      ),
                      if (widget.compact && entries.length > 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${entries.length - 5} flere innlegg finnes i full dagbok.',
                            style: const TextStyle(color: Color(0xFF61718A)),
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (!widget.compact) ...[
                const SizedBox(height: 16),
                _printButtons(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _header({required bool canCreate}) {
    const title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DiaryHeaderIcon(),
        SizedBox(width: 11),
        Flexible(
          child: Text(
            'Dagbok / Driftslogg',
            style: TextStyle(
              color: Color(0xFF0A1733),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
    final button = FilledButton.icon(
      onPressed: canCreate && !_busy ? _createEntry : null,
      icon: const Icon(Icons.add),
      label: const Text('Nytt innlegg'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 12),
              button,
            ],
          );
        }
        return Row(
          children: [
            const Expanded(child: title),
            const SizedBox(width: 12),
            button,
          ],
        );
      },
    );
  }

  Widget _periodControl() {
    return SegmentedButton<DiaryPeriod>(
      segments: const [
        ButtonSegment(value: DiaryPeriod.day, label: Text('Dag')),
        ButtonSegment(value: DiaryPeriod.month, label: Text('Måned')),
        ButtonSegment(value: DiaryPeriod.year, label: Text('År')),
      ],
      selected: {_period},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        setState(() {
          _period = selection.first;
          _configureEntriesStream();
        });
      },
    );
  }

  Widget _navigationRow() {
    return Row(
      children: [
        IconButton.outlined(
          tooltip: _previousTooltip,
          onPressed: () => _shiftFocus(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _periodLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF0A1733),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          tooltip: _nextTooltip,
          onPressed: () => _shiftFocus(1),
          icon: const Icon(Icons.chevron_right),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Gå til i dag',
          onPressed: () {
            setState(() {
              _focusDate = DateTime.now();
              _configureEntriesStream();
            });
          },
          icon: const Icon(Icons.today_outlined),
        ),
      ],
    );
  }

  Widget _filterRow() {
    final search = TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        labelText: 'Søk i innlegg',
        prefixIcon: Icon(Icons.search),
        isDense: true,
      ),
    );
    final category = DropdownButtonFormField<String>(
      initialValue: _category,
      decoration: const InputDecoration(
        labelText: 'Kategori',
        prefixIcon: Icon(Icons.category_outlined),
        isDense: true,
      ),
      items: [
        'Alle kategorier',
        ...DiaryService.categories,
      ].map((value) {
        return DropdownMenuItem(value: value, child: Text(value));
      }).toList(),
      onChanged: (value) {
        if (value != null) setState(() => _category = value);
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 680) {
          return Column(
            children: [
              search,
              const SizedBox(height: 12),
              category,
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 2, child: search),
            const SizedBox(width: 12),
            Expanded(child: category),
          ],
        );
      },
    );
  }

  Widget _printButtons() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        OutlinedButton.icon(
          onPressed: _busy ? null : _printMonth,
          icon: const Icon(Icons.calendar_month_outlined),
          label: const Text('Skriv ut måned'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _printYear,
          icon: const Icon(Icons.event_note_outlined),
          label: const Text('Skriv ut år'),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 34),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E7F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.menu_book_outlined, size: 36, color: Color(0xFF7A8AA0)),
          SizedBox(height: 10),
          Text(
            'Ingen dagbokinnlegg i valgt periode',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _errorState(Object? error) {
    if (kDebugMode) {
      debugPrint('Fjellfisk diary load error: $error');
    }
    final permissionDenied =
        error is FirebaseException && error.code == 'permission-denied';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF0DCA5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF9A6700)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              permissionDenied
                  ? 'Driftsloggen er ikke tilgjengelig før tilgangsreglene er oppdatert.'
                  : 'Driftsloggen kunne ikke lastes akkurat nå. Resten av dashboardet fungerer som normalt.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeoutState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E7F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: Color(0xFF61718A)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Driftsloggen bruker lang tid på å svare. Resten av dashboardet fungerer som normalt.',
            ),
          ),
          const SizedBox(width: 12),
          TextButton.icon(
            onPressed: _retryEntries,
            icon: const Icon(Icons.refresh),
            label: const Text('Prøv igjen'),
          ),
        ],
      ),
    );
  }

  List<DiaryEntry> _filterEntries(List<DiaryEntry> entries) {
    final query = _searchController.text.trim().toLowerCase();
    return entries.where((entry) {
      if (_category != 'Alle kategorier' && entry.category != _category) {
        return false;
      }
      if (query.isEmpty) return true;
      final searchable = [
        entry.title,
        entry.body,
        entry.category,
        entry.createdByName,
        entry.createdByEmail,
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  bool _canEdit(String role, DiaryEntry entry) {
    if (role == 'admin') return true;
    return role == 'ansatt' &&
        entry.createdByUid == FirebaseAuth.instance.currentUser?.uid;
  }

  void _shiftFocus(int amount) {
    setState(() {
      _focusDate = DiaryService.shiftFocus(_period, _focusDate, amount);
      _configureEntriesStream();
    });
  }

  void _configureEntriesStream() {
    final range = DiaryService.rangeFor(_period, _focusDate);
    _entriesStream = DiaryService.entriesStream(
      facilityId: widget.facilityId,
      range: range,
    );
    _waitingForFirstEntries = true;
    _initialLoadTimedOut = false;
    _initialLoadTimer?.cancel();
    _initialLoadTimer = Timer(const Duration(seconds: 20), () {
      if (!mounted || !_waitingForFirstEntries) return;
      setState(() => _initialLoadTimedOut = true);
    });
  }

  void _finishInitialLoad() {
    if (!_waitingForFirstEntries) return;
    _waitingForFirstEntries = false;
    _initialLoadTimer?.cancel();
  }

  void _retryEntries() {
    setState(_configureEntriesStream);
  }

  Future<void> _createEntry() async {
    final draft = await showDialog<DiaryDraft>(
      context: context,
      builder: (_) => const _DiaryEditorDialog(),
    );
    if (draft == null || !mounted) return;

    await _runAction(
      action: () => DiaryService.createEntry(
        facilityId: widget.facilityId,
        draft: draft,
      ),
      success: 'Dagbokinnlegg lagret',
      failure: 'Kunne ikke lagre dagbokinnlegg',
    );
  }

  Future<void> _editEntry(DiaryEntry entry) async {
    final draft = await showDialog<DiaryDraft>(
      context: context,
      builder: (_) => _DiaryEditorDialog(entry: entry),
    );
    if (draft == null || !mounted) return;

    await _runAction(
      action: () => DiaryService.updateEntry(
        facilityId: widget.facilityId,
        entry: entry,
        draft: draft,
      ),
      success: 'Dagbokinnlegg oppdatert',
      failure: 'Kunne ikke oppdatere dagbokinnlegg',
    );
  }

  Future<void> _archiveEntry(DiaryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arkiver innlegg?'),
        content: Text('«${entry.title}» fjernes fra den aktive dagboken.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Arkiver'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _runAction(
      action: () => DiaryService.archiveEntry(
        facilityId: widget.facilityId,
        entry: entry,
      ),
      success: 'Dagbokinnlegg arkivert',
      failure: 'Kunne ikke arkivere dagbokinnlegg',
    );
  }

  Future<void> _printEntry(DiaryEntry entry) async {
    await _runAction(
      action: () => DiaryPrintService.printEntry(
        entry: entry,
        facilityName: widget.facilityName,
      ),
      failure: 'Kunne ikke åpne utskrift',
    );
  }

  Future<void> _printMonth() async {
    final range = DiaryService.rangeFor(DiaryPeriod.month, _focusDate);
    await _printRange(
      range: range,
      periodLabel:
          '${DateFormat('dd.MM.yyyy').format(range.start)}–${DateFormat('dd.MM.yyyy').format(range.endExclusive.subtract(const Duration(days: 1)))}',
      fileName:
          'fjellfisk_dagbok_${DateFormat('yyyy-MM').format(range.start)}.pdf',
    );
  }

  Future<void> _printYear() async {
    final range = DiaryService.rangeFor(DiaryPeriod.year, _focusDate);
    await _printRange(
      range: range,
      periodLabel: '${range.start.year}',
      fileName: 'fjellfisk_dagbok_${range.start.year}.pdf',
    );
  }

  Future<void> _printRange({
    required DiaryDateRange range,
    required String periodLabel,
    required String fileName,
  }) async {
    await _runAction(
      action: () async {
        final entries = await DiaryService.fetchEntries(
          facilityId: widget.facilityId,
          range: range,
        );
        await DiaryPrintService.printPeriod(
          entries: entries,
          facilityName: widget.facilityName,
          periodLabel: periodLabel,
          fileName: fileName,
        );
      },
      failure: 'Kunne ikke åpne utskrift',
    );
  }

  Future<void> _runAction({
    required Future<void> Function() action,
    String? success,
    required String failure,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted || success == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success)),
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Fjellfisk diary action error: $error\n$stackTrace');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _periodLabel {
    switch (_period) {
      case DiaryPeriod.day:
        return DateFormat('dd.MM.yyyy').format(_focusDate);
      case DiaryPeriod.month:
        return DateFormat('MM.yyyy').format(_focusDate);
      case DiaryPeriod.year:
        return '${_focusDate.year}';
    }
  }

  String get _previousTooltip => switch (_period) {
        DiaryPeriod.day => 'Forrige dag',
        DiaryPeriod.month => 'Forrige måned',
        DiaryPeriod.year => 'Forrige år',
      };

  String get _nextTooltip => switch (_period) {
        DiaryPeriod.day => 'Neste dag',
        DiaryPeriod.month => 'Neste måned',
        DiaryPeriod.year => 'Neste år',
      };
}

class _DiaryHeaderIcon extends StatelessWidget {
  const _DiaryHeaderIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFD4E6FF)),
      ),
      child: const Icon(
        Icons.menu_book_outlined,
        size: 20,
        color: Color(0xFF0B63E5),
      ),
    );
  }
}

class _DiaryEditorDialog extends StatefulWidget {
  const _DiaryEditorDialog({this.entry});

  final DiaryEntry? entry;

  @override
  State<_DiaryEditorDialog> createState() => _DiaryEditorDialogState();
}

class _DiaryEditorDialogState extends State<_DiaryEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late String _category;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry?.title ?? '');
    _bodyController = TextEditingController(text: widget.entry?.body ?? '');
    final existingCategory = widget.entry?.category;
    _category = DiaryService.categories.contains(existingCategory)
        ? existingCategory!
        : 'Annet';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.entry == null ? 'Nytt innlegg' : 'Rediger innlegg'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  maxLength: 160,
                  decoration: const InputDecoration(labelText: 'Tittel'),
                  validator: (value) {
                    return value == null || value.trim().isEmpty
                        ? 'Skriv inn en tittel'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: DiaryService.categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bodyController,
                  minLines: 5,
                  maxLines: 10,
                  maxLength: 10000,
                  decoration: const InputDecoration(
                    labelText: 'Tekst / innhold',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    return value == null || value.trim().isEmpty
                        ? 'Skriv inn hva som har skjedd eller er gjort'
                        : null;
                  },
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_outlined,
                      size: 18,
                      color: Color(0xFF61718A),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.entry == null
                            ? 'Dato og klokkeslett lagres automatisk.'
                            : 'Opprinnelig dato beholdes. Endringstid lagres automatisk.',
                        style: const TextStyle(
                          color: Color(0xFF61718A),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Avbryt'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Lagre'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      DiaryDraft(
        title: _titleController.text,
        body: _bodyController.text,
        category: _category,
      ),
    );
  }
}

class _DiaryEntryCard extends StatelessWidget {
  const _DiaryEntryCard({
    required this.entry,
    required this.canEdit,
    required this.canArchive,
    required this.onEdit,
    required this.onArchive,
    required this.onPrint,
  });

  final DiaryEntry entry;
  final bool canEdit;
  final bool canArchive;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFDCE4EE)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 620;
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _metaRow(context),
                const SizedBox(height: 10),
                _content(context, showActions: false),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 145, child: _meta(context)),
              const SizedBox(width: 14),
              Container(width: 1, height: 76, color: const Color(0xFFDCE4EE)),
              const SizedBox(width: 18),
              Expanded(child: _content(context, showActions: true)),
            ],
          );
        },
      ),
    );
  }

  Widget _metaRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _meta(context)),
        _actions(),
      ],
    );
  }

  Widget _meta(BuildContext context) {
    final date = entry.displayDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          date == null ? 'Dato mangler' : DateFormat('dd.MM.yyyy').format(date),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          date == null ? '' : DateFormat('HH:mm').format(date),
          style: const TextStyle(color: Color(0xFF61718A)),
        ),
        const SizedBox(height: 7),
        Text(
          entry.authorLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF53657D), fontSize: 13),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, {required bool showActions}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                entry.title,
                style: const TextStyle(
                  color: Color(0xFF0A1733),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _CategoryBadge(category: entry.category),
            if (showActions) ...[
              const SizedBox(width: 4),
              _actions(),
            ],
          ],
        ),
        if (entry.body.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            entry.body,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(height: 1.45, color: Color(0xFF34445D)),
          ),
        ],
      ],
    );
  }

  Widget _actions() {
    return PopupMenuButton<String>(
      tooltip: 'Handlinger for innlegg',
      onSelected: (value) {
        if (value == 'print') onPrint();
        if (value == 'edit') onEdit();
        if (value == 'archive') onArchive();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'print',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.print_outlined),
            title: Text('Skriv ut innlegg'),
          ),
        ),
        if (canEdit)
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_outlined),
              title: Text('Rediger'),
            ),
          ),
        if (canArchive)
          const PopupMenuItem(
            value: 'archive',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.archive_outlined),
              title: Text('Arkiver'),
            ),
          ),
      ],
      icon: const Icon(Icons.more_vert, color: Color(0xFF53657D)),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final color = switch (category) {
      'Hendelse' => const Color(0xFF0B63E5),
      'Vedlikehold' => const Color(0xFF16875A),
      'Observasjon' => const Color(0xFFC47A00),
      'Fôring' => const Color(0xFF6D4AD8),
      'Service' => const Color(0xFF147D92),
      _ => const Color(0xFF64748B),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        category,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
