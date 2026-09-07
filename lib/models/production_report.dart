class ReportOption {
  final String id;
  final String name;

  const ReportOption({
    required this.id,
    required this.name,
  });
}

class ProductionReport {
  final DateTime from;
  final DateTime to;
  final String scope;
  final String filterLabel;
  final int activeTanks;
  final int emptyTanks;
  final int activeFish;
  final int registrations;
  final int mortality;
  final double feedKg;
  final double biomassKg;
  final double latestAvgWeight;
  final double weightChange;
  final double biomassGainKg;
  final double? fcr;
  final double? avgTemperature;
  final double? minTemperature;
  final double? maxTemperature;
  final List<ProductionReportTankRow> tanks;
  final List<ProductionReportRegistration> registrationsList;

  const ProductionReport({
    required this.from,
    required this.to,
    required this.scope,
    required this.filterLabel,
    required this.activeTanks,
    required this.emptyTanks,
    required this.activeFish,
    required this.registrations,
    required this.mortality,
    required this.feedKg,
    required this.biomassKg,
    required this.latestAvgWeight,
    required this.weightChange,
    required this.biomassGainKg,
    required this.fcr,
    required this.avgTemperature,
    required this.minTemperature,
    required this.maxTemperature,
    required this.tanks,
    required this.registrationsList,
  });
}

class ProductionReportTankRow {
  final String sectionId;
  final String sectionName;
  final String tankId;
  final String tankName;
  final int fishCount;
  final bool isActive;
  final double latestWeight;
  final double biomassKg;
  final double feedKg;
  final int mortality;
  final double? fcr;
  final double? latestTemperature;
  final double weightChange;
  final int registrations;

  const ProductionReportTankRow({
    required this.sectionId,
    required this.sectionName,
    required this.tankId,
    required this.tankName,
    required this.fishCount,
    required this.isActive,
    required this.latestWeight,
    required this.biomassKg,
    required this.feedKg,
    required this.mortality,
    required this.fcr,
    required this.latestTemperature,
    required this.weightChange,
    required this.registrations,
  });
}

class ProductionReportRegistration {
  final DateTime date;
  final String sectionName;
  final String tankName;
  final int mortality;
  final double feedKg;
  final double avgWeight;
  final double temperature;
  final String feedType;
  final double pelletSizeMm;

  const ProductionReportRegistration({
    required this.date,
    required this.sectionName,
    required this.tankName,
    required this.mortality,
    required this.feedKg,
    required this.avgWeight,
    required this.temperature,
    required this.feedType,
    required this.pelletSizeMm,
  });
}
