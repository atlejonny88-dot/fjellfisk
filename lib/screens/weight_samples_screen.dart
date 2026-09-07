import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/weight_sample.dart';
import '../services/firestore_service.dart';
import '../services/user_service.dart';
import '../services/weight_sample_service.dart';
import '../utils/tank_status.dart';

class WeightSamplesScreen extends StatefulWidget {
  final String facilityId;
  final String sectionId;
  final String tankId;
  final String tankName;
  final int fishCount;

  const WeightSamplesScreen({
    super.key,
    required this.facilityId,
    required this.sectionId,
    required this.tankId,
    required this.tankName,
    required this.fishCount,
  });

  @override
  State<WeightSamplesScreen> createState() => _WeightSamplesScreenState();
}

class _WeightSamplesScreenState extends State<WeightSamplesScreen> {
  final _singleWeightCtrl = TextEditingController();
  final _sampleWeightCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _weights = <double>[];
  var _mode = 'single';
  var _isSaving = false;

  @override
  void dispose() {
    _singleWeightCtrl.dispose();
    _sampleWeightCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool _canWrite(String role) {
    return role == 'admin' || role == 'ansatt';
  }

  bool _isActive() {
    return TankStatus.isActiveFishCount(widget.fishCount);
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _addWeightsFromInput() {
    final result = WeightSampleService.parseWeights(_sampleWeightCtrl.text);

    if (result.validWeights.isEmpty && result.invalidValues.isEmpty) {
      _showMessage('Skriv inn en vekt først.');
      return;
    }

    setState(() {
      _weights.addAll(result.validWeights);
      _sampleWeightCtrl.clear();
    });

    if (result.invalidValues.isNotEmpty) {
      _showMessage(
        'Noen verdier ble ikke lagt til: ${result.invalidValues.join(', ')}',
      );
    }
  }

  Future<void> _saveSingleWeight() async {
    final result = WeightSampleService.parseWeights(_singleWeightCtrl.text);
    if (result.validWeights.length != 1 || result.invalidValues.isNotEmpty) {
      _showMessage('Ugyldig snittvekt');
      return;
    }

    await _save(() {
      return FirestoreService.addDailyLog(
        facilityId: widget.facilityId,
        sectionId: widget.sectionId,
        tankId: widget.tankId,
        mortality: 0,
        feedKg: 0,
        avgWeight: result.validWeights.first,
        temperature: 0,
      );
    }, 'Snittvekt lagret');
  }

  Future<void> _saveSample() async {
    if (_weights.isEmpty) {
      _showMessage('Legg til minst én vekt før lagring.');
      return;
    }

    await _save(() {
      return WeightSampleService.saveWeightSample(
        facilityId: widget.facilityId,
        sectionId: widget.sectionId,
        tankId: widget.tankId,
        weightsGram: _weights,
        note: _noteCtrl.text,
      );
    }, 'Vektprøve lagret');

    if (!mounted) return;
    setState(() {
      _weights.clear();
      _noteCtrl.clear();
    });
  }

  Future<void> _save(Future<void> Function() action, String successText) async {
    if (!_isActive()) {
      _showMessage('Karet er tomt. Legg inn fisketall før vekt registreres.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await action();
      if (!mounted) return;
      _showMessage(successText);
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      _showMessage('Kunne ikke lagre vekt: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: UserService.getCurrentUserRole(),
      builder: (context, roleSnapshot) {
        final role = roleSnapshot.data ?? 'leser';
        final canWrite = _canWrite(role);
        final isActive = _isActive();

        return Scaffold(
          appBar: AppBar(title: Text('Vektprøve - ${widget.tankName}')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!canWrite)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.visibility),
                    title: const Text('Lesetilgang'),
                    subtitle: Text('Du er logget inn som $role og kan kun se.'),
                  ),
                ),
              if (!isActive)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.pause_circle),
                    title: Text('Tomt kar'),
                    subtitle: Text(
                      'Vektprøve kan registreres når karet har fisk.',
                    ),
                  ),
                ),
              if (canWrite && isActive) _registrationCard(),
              const SizedBox(height: 12),
              _historySection(),
            ],
          ),
        );
      },
    );
  }

  Widget _registrationCard() {
    final stats =
        _weights.isEmpty ? null : WeightSampleService.calculateStats(_weights);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Registrer vekt',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'single',
                  label: Text('Vanlig snittvekt'),
                  icon: Icon(Icons.monitor_weight),
                ),
                ButtonSegment(
                  value: 'sample',
                  label: Text('Enkeltvekter'),
                  icon: Icon(Icons.format_list_numbered),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (values) {
                setState(() => _mode = values.first);
              },
            ),
            const SizedBox(height: 14),
            if (_mode == 'single') ...[
              TextField(
                controller: _singleWeightCtrl,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Snittvekt (g)',
                  helperText: 'Støtter 250, 250.5 og 250,5',
                ),
                onSubmitted: (_) => _isSaving ? null : _saveSingleWeight(),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveSingleWeight,
                icon: const Icon(Icons.save),
                label: const Text('Lagre snittvekt'),
              ),
            ] else ...[
              TextField(
                controller: _sampleWeightCtrl,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.done,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Vekt i gram',
                  helperText:
                      'Én eller flere vekter. Bruk komma, mellomrom eller linjeskift.',
                ),
                onSubmitted: (_) => _addWeightsFromInput(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addWeightsFromInput,
                      icon: const Icon(Icons.add),
                      label: const Text('Legg til'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _weights.isEmpty
                          ? null
                          : () => setState(_weights.clear),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Tøm liste'),
                    ),
                  ),
                ],
              ),
              if (_weights.isNotEmpty) ...[
                const SizedBox(height: 12),
                _statsPreview(stats!),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _weights.asMap().entries.map((entry) {
                    return InputChip(
                      label: Text('${entry.value.toStringAsFixed(1)} g'),
                      onDeleted: () {
                        setState(() => _weights.removeAt(entry.key));
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Kommentar',
                    hintText: 'Valgfritt',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveSample,
                icon: const Icon(Icons.save),
                label: const Text('Lagre vektprøve'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statsPreview(WeightSampleStats stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _smallValue('Antall', stats.count.toString()),
          _smallValue('Snitt', '${stats.averageGram.toStringAsFixed(1)} g'),
          _smallValue('Median', '${stats.medianGram.toStringAsFixed(1)} g'),
          _smallValue('Min', '${stats.minGram.toStringAsFixed(1)} g'),
          _smallValue('Maks', '${stats.maxGram.toStringAsFixed(1)} g'),
          _smallValue(
            'Std.avvik',
            '${stats.standardDeviationGram.toStringAsFixed(1)} g',
          ),
        ],
      ),
    );
  }

  Widget _historySection() {
    return StreamBuilder<List<WeightSample>>(
      stream: WeightSampleService.samplesStream(
        facilityId: widget.facilityId,
        sectionId: widget.sectionId,
        tankId: widget.tankId,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (kDebugMode) {
            debugPrint('Kunne ikke laste vektprøver: ${snapshot.error}');
          }
          return const Card(
            child: ListTile(
              leading: Icon(Icons.error_outline),
              title: Text('Vektprøver'),
              subtitle: Text('Vektprøver er ikke tilgjengelige nå.'),
            ),
          );
        }

        final samples = snapshot.data ?? const <WeightSample>[];
        if (samples.isEmpty) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.monitor_weight),
              title: Text('Vektprøver'),
              subtitle: Text('Ingen vektprøver er registrert ennå.'),
            ),
          );
        }

        final latest = samples.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Siste vektprøve',
                style: Theme.of(context).textTheme.titleMedium),
            _sampleCard(latest, initiallyExpanded: true),
            const SizedBox(height: 12),
            Text('Historikk', style: Theme.of(context).textTheme.titleMedium),
            ...samples.skip(1).map(_sampleCard),
          ],
        );
      },
    );
  }

  Widget _sampleCard(
    WeightSample sample, {
    bool initiallyExpanded = false,
  }) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: const Icon(Icons.monitor_weight),
        title: Text(
          '${sample.averageGram.toStringAsFixed(1)} g snitt '
          '(${sample.count} fisk)',
        ),
        subtitle: Text(
          '${_formatDate(sample.date)}\n${sample.createdByEmail}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _statsPreview(
            WeightSampleStats(
              weightsGram: sample.weightsGram,
              count: sample.count,
              averageGram: sample.averageGram,
              medianGram: sample.medianGram,
              minGram: sample.minGram,
              maxGram: sample.maxGram,
              standardDeviationGram: sample.standardDeviationGram,
              spreadGram: sample.spreadGram,
              distribution: sample.distribution,
            ),
          ),
          const SizedBox(height: 12),
          _distribution(sample.distribution),
          if (sample.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Kommentar: ${sample.note}'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _distribution(Map<String, int> distribution) {
    final total = distribution.values.fold<int>(0, (sum, value) => sum + value);
    if (total == 0) return const Text('Ingen fordeling tilgjengelig.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: distribution.entries.map((entry) {
        final fraction = entry.value / total;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 110, child: Text(entry.key)),
              Expanded(
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 8,
                ),
              ),
              const SizedBox(width: 8),
              Text(entry.value.toString()),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _smallValue(String label, String value) {
    return SizedBox(
      width: 105,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Ukjent tidspunkt';
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }
}
