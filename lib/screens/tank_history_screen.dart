import '../utils/load_error.dart';
import '../utils/data_values.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TankHistoryScreen extends StatefulWidget {
  final String facilityId;
  final String sectionId;
  final String tankId;
  final String tankName;
  final FirebaseFirestore? firestore;

  const TankHistoryScreen({
    super.key,
    required this.facilityId,
    required this.sectionId,
    required this.tankId,
    required this.tankName,
    this.firestore,
  });

  @override
  State<TankHistoryScreen> createState() => _TankHistoryScreenState();
}

class _TankHistoryScreenState extends State<TankHistoryScreen> {
  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy');
  DateTime? _from;
  DateTime? _to;
  String _type = 'all';
  late final Future<String> _sectionName;

  FirebaseFirestore get _firestore =>
      widget.firestore ?? FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _sectionName = _loadSectionName();
  }

  Future<String> _loadSectionName() async {
    try {
      final section = await _firestore
          .collection('facilities')
          .doc(widget.facilityId)
          .collection('sections')
          .doc(widget.sectionId)
          .get()
          .timeout(const Duration(seconds: 10));
      final name = section.data()?['name'];
      if (name is String && name.trim().isNotEmpty) return name.trim();
    } catch (error, stackTrace) {
      debugPrint('TankHistoryScreen: kunne ikke hente seksjonsnavn: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    return 'Navn ikke tilgjengelig';
  }

  Query<Map<String, dynamic>> get _logsQuery {
    return _firestore
        .collection('facilities')
        .doc(widget.facilityId)
        .collection('sections')
        .doc(widget.sectionId)
        .collection('tanks')
        .doc(widget.tankId)
        .collection('logs')
        .orderBy('date', descending: true);
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (picked == null) return;

    setState(() {
      if (isFrom) {
        _from = _startOfDay(picked);
        if (_to != null && _from!.isAfter(_to!)) _to = _endOfDay(picked);
      } else {
        _to = _endOfDay(picked);
        if (_from != null && _to!.isBefore(_from!)) _from = _startOfDay(picked);
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _from = null;
      _to = null;
      _type = 'all';
    });
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final data = doc.data();
      final date = _toDate(data['date']);

      if (_from != null && (date == null || date.isBefore(_from!))) {
        return false;
      }
      if (_to != null && (date == null || date.isAfter(_to!))) {
        return false;
      }

      switch (_type) {
        case 'mortality':
          return _toDouble(data['mortality'] ?? data['dead']) > 0;
        case 'feed':
          return _toDouble(data['feedKg'] ?? data['feed']) > 0;
        case 'weight':
          return DataValues.weight(data) > 0;
        case 'temperature':
          return _toDouble(data['temperature']) > 0;
        case 'note':
          return _firstText([data['note'], data['notes'], data['comment']])
              .isNotEmpty;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Historikk - ${widget.tankName}')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _logsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(loadErrorMessage(snapshot.error)));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = _filterDocs(snapshot.data!.docs);

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _filters(),
              const SizedBox(height: 8),
              if (docs.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.info),
                    title: Text('Ingen registreringer funnet'),
                    subtitle: Text('Prøv å endre filter eller periode.'),
                  ),
                )
              else
                ...docs.map(_historyCard),
            ],
          );
        },
      ),
    );
  }

  Widget _filters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<String>(
              future: _sectionName,
              builder: (context, snapshot) => Text(
                'Kar: ${widget.tankName}\nBygg/seksjon: '
                '${snapshot.data ?? 'Navn ikke tilgjengelig'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type registrering'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Alle')),
                DropdownMenuItem(value: 'mortality', child: Text('Dødelighet')),
                DropdownMenuItem(value: 'feed', child: Text('Fôr')),
                DropdownMenuItem(value: 'weight', child: Text('Snittvekt')),
                DropdownMenuItem(
                  value: 'temperature',
                  child: Text('Temperatur'),
                ),
                DropdownMenuItem(value: 'note', child: Text('Notater')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _type = value);
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _from == null
                          ? 'Fra dato'
                          : 'Fra ${_dateFormat.format(_from!)}',
                    ),
                    onPressed: () => _pickDate(isFrom: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(
                      _to == null
                          ? 'Til dato'
                          : 'Til ${_dateFormat.format(_to!)}',
                    ),
                    onPressed: () => _pickDate(isFrom: false),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.clear),
                label: const Text('Nullstill filter'),
                onPressed: _clearFilters,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final date = _toDate(data['date']);
    final mortality = _toInt(data['mortality'] ?? data['dead']);
    final feedKg = _toDouble(data['feedKg'] ?? data['feed']);
    final avgWeight = DataValues.weight(data);
    final temperature = _toDouble(data['temperature']);
    final note = _firstText([data['note'], data['notes'], data['comment']]);
    final feedType = _firstText([
      data['feedType'],
      data['feedName'],
      data['feed_type'],
      data['feed_type_name'],
    ]);
    final pelletSizeMm = _toDouble(
      _firstValue([
        data['pelletSizeMm'],
        data['pelletSizeMM'],
        data['pelletSize'],
        data['pellet_mm'],
      ]),
    );

    return Card(
      child: ListTile(
        leading: const Icon(Icons.history),
        title: Text(date == null ? 'Ukjent dato' : _dateFormat.format(date)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Død: $mortality  •  Fôr: ${_formatDecimal(feedKg)} kg'),
              if (feedKg > 0 && feedType.isNotEmpty)
                Text(
                  'Fôrtype: $feedType',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              if (feedKg > 0 && pelletSizeMm > 0)
                Text('Pellet: ${_formatDecimal(pelletSizeMm)} mm'),
              Text(
                'Vekt: ${_formatDecimal(avgWeight)} g  •  '
                'Temp: ${_formatDecimal(temperature)} °C',
              ),
              if (note.isNotEmpty) Text('Notat: $note'),
            ],
          ),
        ),
      ),
    );
  }

  DateTime _startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _endOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day, 23, 59, 59, 999);
  }

  DateTime? _toDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  double _toDouble(Object? value) => DataValues.decimal(value);

  int _toInt(Object? value) => DataValues.integer(value);

  String _firstText(List<Object?> values) {
    final value = _firstValue(values);
    return value?.toString().trim() ?? '';
  }

  Object? _firstValue(List<Object?> values) {
    for (final value in values) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return value;
    }
    return null;
  }

  String _formatDecimal(double value) {
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }
}
