/// WHOOP export values retain their documented units. In older imported bundles
/// absolute Celsius was unfortunately named skin_temp_z. Never render it as SD.
/// This is a read-only compatibility adapter, not a new analytics computation.
Map<String, dynamic> importedVitals(Map<String, dynamic>? bundle) {
  if (bundle == null ||
      bundle['source'] != 'whoop_export' ||
      bundle['imported'] != true) {
    return const {};
  }
  final raw = bundle['scalars'];
  if (raw is! Map) return const {};
  num? finite(Object? value, num lo, num hi) =>
      value is num && value.isFinite && value >= lo && value <= hi
      ? value
      : null;
  return {
    'source': 'whoop_export',
    'date': bundle['date'],
    'spo2_pct': finite(raw['spo2'], 50, 100),
    'skin_temperature_c': finite(
      raw['skin_temperature_c'] ?? raw['skin_temp_z'],
      20,
      45,
    ),
  };
}
