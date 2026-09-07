import 'package:flutter/material.dart';

import '../models/production_report.dart';
import '../services/excel_service.dart';
import '../services/production_report_service.dart';

class ProductionReportScreen extends StatefulWidget {
  final String facilityId;
  final String facilityName;

  const ProductionReportScreen({
    super.key,
    required this.facilityId,
    required this.facilityName,
  });

  @override
  State<ProductionReportScreen> createState() => _ProductionReportScreenState();
}

class _ProductionReportScreenState extends State<ProductionReportScreen> {
  String _period = '7d';
  String _scope = 'facility';
  String? _sectionId;
  String? _tankId;
  late DateTime _from;
  late DateTime _to;
  late Future<List<ReportOption>> _sectionsFuture;
  var _isExporting = false;

  @override
  void initState() {
    super.initState();
    _from = ProductionReportService.fromForPeriod(_period);
    _to = ProductionReportService.startOfDay(DateTime.now());
    _sectionsFuture = ProductionReportService.loadSections(widget.facilityId);
  }

  void _setPeriod(String value) {
    setState(() {
      _period = value;
      if (value != 'custom') {
        _from = ProductionReportService.fromForPeriod(value);
        _to = ProductionReportService.startOfDay(DateTime.now());
      }
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (picked == null) return;

    setState(() {
      _period = 'custom';
      if (isFrom) {
        _from = picked;
        if (_from.isAfter(_to)) _to = _from;
      } else {
        _to = picked;
        if (_to.isBefore(_from)) _from = _to;
      }
    });
  }

  Future<ProductionReport>? _reportFuture() {
    if (_scope == 'section' && _sectionId == null) return null;
    if (_scope == 'tank' && (_sectionId == null || _tankId == null)) {
      return null;
    }

    return ProductionReportService.loadProductionReport(
      facilityId: widget.facilityId,
      from: _from,
      to: _to,
      sectionId: _scope == 'facility' ? null : _sectionId,
      tankId: _scope == 'tank' ? _tankId : null,
    );
  }

  Future<void> _exportReport(ProductionReport report) async {
    setState(() => _isExporting = true);

    try {
      await ExcelService.exportProductionReport(
        report: report,
        facilityName: widget.facilityName,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel eksport fullført')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kunne ikke eksportere rapport: $error')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportFuture = _reportFuture();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produksjonsrapport'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _filters(),
            const SizedBox(height: 12),
            if (reportFuture == null)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.info),
                  title: Text('Velg bygg eller kar'),
                  subtitle: Text('Rapporten vises når valget er komplett.'),
                ),
              )
            else
              FutureBuilder<ProductionReport>(
                future: reportFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.error_outline),
                        title: const Text('Kunne ikke lage rapport'),
                        subtitle: Text(snapshot.error.toString()),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  return _report(snapshot.data!);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _filters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _period,
              decoration: const InputDecoration(labelText: 'Periode'),
              items: const [
                DropdownMenuItem(value: 'today', child: Text('I dag')),
                DropdownMenuItem(value: '7d', child: Text('Siste 7 dager')),
                DropdownMenuItem(value: '30d', child: Text('Siste 30 dager')),
                DropdownMenuItem(value: 'month', child: Text('Denne måneden')),
                DropdownMenuItem(
                  value: 'custom',
                  child: Text('Egendefinert periode'),
                ),
              ],
              onChanged: (value) {
                if (value != null) _setPeriod(value);
              },
            ),
            if (_period == 'custom') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        'Fra ${ProductionReportService.dateFormat.format(_from)}',
                      ),
                      onPressed: () => _pickDate(isFrom: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event),
                      label: Text(
                        'Til ${ProductionReportService.dateFormat.format(_to)}',
                      ),
                      onPressed: () => _pickDate(isFrom: false),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _scope,
              decoration: const InputDecoration(labelText: 'Rapport for'),
              items: const [
                DropdownMenuItem(
                    value: 'facility', child: Text('Hele anlegget')),
                DropdownMenuItem(value: 'section', child: Text('Bygg/seksjon')),
                DropdownMenuItem(value: 'tank', child: Text('Enkelt kar')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _scope = value;
                  _sectionId = null;
                  _tankId = null;
                });
              },
            ),
            if (_scope != 'facility') ...[
              const SizedBox(height: 12),
              FutureBuilder<List<ReportOption>>(
                future: _sectionsFuture,
                builder: (context, snapshot) {
                  final sections = snapshot.data ?? const <ReportOption>[];
                  return DropdownButtonFormField<String>(
                    initialValue: _sectionId,
                    decoration:
                        const InputDecoration(labelText: 'Bygg/seksjon'),
                    isExpanded: true,
                    items: sections
                        .map(
                          (section) => DropdownMenuItem(
                            value: section.id,
                            child: Text(section.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _sectionId = value;
                        _tankId = null;
                      });
                    },
                  );
                },
              ),
            ],
            if (_scope == 'tank' && _sectionId != null) ...[
              const SizedBox(height: 12),
              FutureBuilder<List<ReportOption>>(
                future: ProductionReportService.loadTanks(
                  facilityId: widget.facilityId,
                  sectionId: _sectionId!,
                ),
                builder: (context, snapshot) {
                  final tanks = snapshot.data ?? const <ReportOption>[];
                  return DropdownButtonFormField<String>(
                    initialValue: _tankId,
                    decoration: const InputDecoration(labelText: 'Kar'),
                    isExpanded: true,
                    items: tanks
                        .map(
                          (tank) => DropdownMenuItem(
                            value: tank.id,
                            child: Text(tank.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _tankId = value),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _report(ProductionReport report) {
    final period = ProductionReportService.periodLabel(report.from, report.to);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.summarize),
            title: Text('${widget.facilityName} - ${report.filterLabel}'),
            subtitle: Text(period),
            trailing: IconButton(
              tooltip: 'Eksporter til Excel',
              onPressed: _isExporting ? null : () => _exportReport(report),
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
            ),
          ),
        ),
        if (report.registrations == 0)
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Ingen registreringer i valgt periode'),
              subtitle: Text(
                'Karstatus og siste biomasse vises der datagrunnlag finnes.',
              ),
            ),
          ),
        _kpiGrid(report),
        const SizedBox(height: 12),
        Text('Karoversikt', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _tankOverview(report),
      ],
    );
  }

  Widget _kpiGrid(ProductionReport report) {
    final metrics = [
      _Metric('Fôr brukt', '${report.feedKg.toStringAsFixed(1)} kg',
          Icons.restaurant),
      _Metric('Dødelighet', report.mortality.toString(), Icons.warning),
      _Metric('Biomasse', _kgOrFallback(report.biomassKg, tonnes: true),
          Icons.scale),
      _Metric('Siste snittvekt', _gramsOrFallback(report.latestAvgWeight),
          Icons.monitor_weight),
      _Metric('Vektendring', _signedGramsOrFallback(report.weightChange),
          Icons.trending_up),
      _Metric('FCR', report.fcr?.toStringAsFixed(2) ?? 'FCR kan ikke beregnes',
          Icons.show_chart),
      _Metric('Aktive kar', report.activeTanks.toString(), Icons.water),
      _Metric('Tomme kar', report.emptyTanks.toString(), Icons.pause_circle),
      _Metric(
        'Registreringer',
        report.registrations.toString(),
        Icons.format_list_numbered,
      ),
      _Metric(
        'Temperatur',
        report.avgTemperature == null
            ? 'Ikke nok data'
            : '${report.avgTemperature!.toStringAsFixed(1)} °C\n'
                '${report.minTemperature!.toStringAsFixed(1)}-${report.maxTemperature!.toStringAsFixed(1)} °C',
        Icons.thermostat,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 820
            ? 4
            : constraints.maxWidth > 520
                ? 3
                : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: columns == 2 ? 1.25 : 1.55,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return _metricCard(metric);
          },
        );
      },
    );
  }

  Widget _tankOverview(ProductionReport report) {
    if (report.tanks.isEmpty) {
      return const Card(
        child: ListTile(title: Text('Ingen kar funnet for valgt filter')),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            children: report.tanks.map(_tankCard).toList(),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Seksjon')),
              DataColumn(label: Text('Kar')),
              DataColumn(label: Text('Fisk')),
              DataColumn(label: Text('Snittvekt')),
              DataColumn(label: Text('Biomasse')),
              DataColumn(label: Text('Fôr')),
              DataColumn(label: Text('Død')),
              DataColumn(label: Text('FCR')),
              DataColumn(label: Text('Temp')),
            ],
            rows: report.tanks.map((row) {
              return DataRow(
                color: !row.isActive
                    ? WidgetStateProperty.all(Colors.grey.shade100)
                    : null,
                cells: [
                  DataCell(Text(row.sectionName)),
                  DataCell(Text(row.tankName)),
                  DataCell(Text(row.fishCount.toString())),
                  DataCell(Text(_gramsOrFallback(row.latestWeight))),
                  DataCell(Text(_kgOrFallback(row.biomassKg))),
                  DataCell(Text('${row.feedKg.toStringAsFixed(1)} kg')),
                  DataCell(Text(row.mortality.toString())),
                  DataCell(Text(row.fcr?.toStringAsFixed(2) ?? '-')),
                  DataCell(Text(row.latestTemperature == null
                      ? '-'
                      : '${row.latestTemperature!.toStringAsFixed(1)} °C')),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _tankCard(ProductionReportTankRow row) {
    return Card(
      color: row.isActive ? null : Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  row.isActive ? Icons.water : Icons.pause_circle,
                  color: row.isActive ? const Color(0xFF0B3C5D) : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${row.sectionName} / ${row.tankName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _smallValue('Fisk', row.fishCount.toString()),
                _smallValue('Snittvekt', _gramsOrFallback(row.latestWeight)),
                _smallValue('Biomasse', _kgOrFallback(row.biomassKg)),
                _smallValue('Fôr', '${row.feedKg.toStringAsFixed(1)} kg'),
                _smallValue('Død', row.mortality.toString()),
                _smallValue('FCR', row.fcr?.toStringAsFixed(2) ?? '-'),
                _smallValue(
                  'Temp',
                  row.latestTemperature == null
                      ? '-'
                      : '${row.latestTemperature!.toStringAsFixed(1)} °C',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(_Metric metric) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(metric.icon, color: const Color(0xFF0B3C5D)),
            const SizedBox(height: 8),
            Text(
              metric.value,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              metric.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallValue(String label, String value) {
    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _gramsOrFallback(double value) {
    if (value <= 0) return 'Ikke nok data';
    return '${value.toStringAsFixed(1)} g';
  }

  String _signedGramsOrFallback(double value) {
    if (value == 0) return 'Ikke nok data';
    final prefix = value > 0 ? '+' : '';
    return '$prefix${value.toStringAsFixed(1)} g';
  }

  String _kgOrFallback(double value, {bool tonnes = false}) {
    if (value <= 0) return 'Ikke nok data';
    if (tonnes) return '${(value / 1000).toStringAsFixed(2)} t';
    return '${value.toStringAsFixed(1)} kg';
  }
}

class _Metric {
  final String title;
  final String value;
  final IconData icon;

  const _Metric(this.title, this.value, this.icon);
}
