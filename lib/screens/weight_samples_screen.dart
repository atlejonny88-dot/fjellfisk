import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/weight_sample.dart';
import '../services/firestore_service.dart';
import '../services/user_service.dart';
import '../services/weight_sample_service.dart';
import '../services/web_update_guard.dart';
import '../utils/tank_status.dart';
import '../l10n/localizations.dart';

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
  var _leaving = false;
  late final _roleFuture = UserService.getCurrentUserRole();
  late final _sampleId = WeightSampleService.samplesRef(
    facilityId: widget.facilityId,
    sectionId: widget.sectionId,
    tankId: widget.tankId,
  ).doc().id;

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
      _showMessage(context.l10n.enterWeightFirst);
      return;
    }

    setState(() {
      _weights.addAll(result.validWeights);
      _sampleWeightCtrl.clear();
    });

    if (result.invalidValues.isNotEmpty) {
      _showMessage(
        context.l10n.invalidValuesNotAdded(result.invalidValues.join(', ')),
      );
    }
  }

  Future<void> _saveSingleWeight() async {
    final result = WeightSampleService.parseWeights(_singleWeightCtrl.text);
    if (result.validWeights.length != 1 || result.invalidValues.isNotEmpty) {
      _showMessage(context.l10n.invalidAverageWeight);
      return;
    }

    await _save(() async {
      await FirestoreService.addDailyLog(
        facilityId: widget.facilityId,
        sectionId: widget.sectionId,
        tankId: widget.tankId,
        mortality: 0,
        feedKg: 0,
        avgWeight: result.validWeights.first,
        temperature: 0,
        registrationId: _sampleId,
      );
    }, context.l10n.averageWeightSaved);
  }

  Future<void> _saveSample() async {
    if (_weights.isEmpty) {
      _showMessage(context.l10n.addWeightBeforeSaving);
      return;
    }

    await _save(() async {
      return WeightSampleService.saveWeightSample(
        facilityId: widget.facilityId,
        sectionId: widget.sectionId,
        tankId: widget.tankId,
        weightsGram: List<double>.of(_weights),
        note: _noteCtrl.text,
        sampleId: _sampleId,
      );
    }, context.l10n.weightSampleSaved);
  }

  Future<void> _save(Future<void> Function() action, String successText) async {
    if (_isSaving || _leaving) return;
    if (!_isActive()) {
      _showMessage(context.l10n.emptyTankBeforeWeight);
      return;
    }

    setState(() => _isSaving = true);
    setWebSavePending(true);
    final noWriteAccess = context.l10n.noWriteAccess;
    try {
      if (!_canWrite(await UserService.getCurrentUserRole())) {
        throw StateError(noWriteAccess);
      }
      await action();
      if (!mounted) return;
      _showMessage(successText);
      _leaving = true;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      debugPrint('Kunne ikke lagre vekt: $error');
      _showMessage(context.l10n.couldNotSaveWeight);
    } finally {
      setWebSavePending(false);
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _roleFuture,
      builder: (context, roleSnapshot) {
        final role = roleSnapshot.data ?? 'leser';
        final canWrite = _canWrite(role);
        final isActive = _isActive();

        return PopScope(
            canPop: !_isSaving || _leaving,
            child: Scaffold(
              appBar: AppBar(
                title: Text(context.l10n.weightSampleForTank(widget.tankName)),
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!canWrite)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.visibility),
                        title: Text(context.l10n.readerAccess),
                        subtitle: Text(context.l10n.readOnlyRole(role)),
                      ),
                    ),
                  if (!isActive)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.pause_circle),
                        title: Text(context.l10n.emptyTank),
                        subtitle: Text(context.l10n.emptyTankDescription),
                      ),
                    ),
                  if (canWrite && isActive)
                    AbsorbPointer(
                        absorbing: _isSaving || _leaving,
                        child: _registrationCard()),
                  const SizedBox(height: 12),
                  _historySection(),
                ],
              ),
            ));
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
            Text(
              context.l10n.registerWeight,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'single',
                  label: Text(context.l10n.simpleAverageWeight),
                  icon: const Icon(Icons.monitor_weight),
                ),
                ButtonSegment(
                  value: 'sample',
                  label: Text(context.l10n.individualWeights),
                  icon: const Icon(Icons.format_list_numbered),
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
                decoration: InputDecoration(
                  labelText: context.l10n.averageWeightGram,
                  helperText: context.l10n.averageWeightInputHelp,
                ),
                onSubmitted: (_) => _isSaving ? null : _saveSingleWeight(),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveSingleWeight,
                icon: const Icon(Icons.save),
                label: Text(context.l10n.saveAverageWeight),
              ),
            ] else ...[
              TextField(
                controller: _sampleWeightCtrl,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.done,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: context.l10n.weightInGrams,
                  helperText: context.l10n.weightSampleInputHelp,
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
                      label: Text(context.l10n.add),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _weights.isEmpty
                          ? null
                          : () => setState(_weights.clear),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(context.l10n.clearList),
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
                  decoration: InputDecoration(
                    labelText: context.l10n.comment,
                    hintText: context.l10n.optional,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveSample,
                icon: const Icon(Icons.save),
                label: Text(context.l10n.saveWeightSample),
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
          _smallValue(context.l10n.count, stats.count.toString()),
          _smallValue(context.l10n.average,
              '${stats.averageGram.toStringAsFixed(1)} g'),
          _smallValue(
              context.l10n.median, '${stats.medianGram.toStringAsFixed(1)} g'),
          _smallValue(
              context.l10n.minimum, '${stats.minGram.toStringAsFixed(1)} g'),
          _smallValue(
              context.l10n.maximum, '${stats.maxGram.toStringAsFixed(1)} g'),
          _smallValue(
            context.l10n.standardDeviation,
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
          return Card(
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: Text(context.l10n.weightSamples),
              subtitle: Text(context.l10n.weightSamplesUnavailable),
            ),
          );
        }

        final samples = snapshot.data ?? const <WeightSample>[];
        if (samples.isEmpty) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.monitor_weight),
              title: Text(context.l10n.weightSamples),
              subtitle: Text(context.l10n.noWeightSamples),
            ),
          );
        }

        final latest = samples.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.latestWeightSample,
                style: Theme.of(context).textTheme.titleMedium),
            _sampleCard(latest, initiallyExpanded: true),
            const SizedBox(height: 12),
            Text(context.l10n.history,
                style: Theme.of(context).textTheme.titleMedium),
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
          context.l10n.sampleSummary(
            sample.averageGram.toStringAsFixed(1),
            sample.count,
          ),
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
              child: Text(context.l10n.commentLine(sample.note)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _distribution(Map<String, int> distribution) {
    final total = distribution.values.fold<int>(0, (sum, value) => sum + value);
    if (total == 0) return Text(context.l10n.noDistribution);

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
    if (date == null) return context.l10n.unknownTime;
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }
}
