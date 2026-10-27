class ImportRowFailure {
  const ImportRowFailure({
    required this.sourceLine,
    required this.message,
    this.sourceValues = const {},
  });

  final int sourceLine;
  final String message;
  final Map<String, String> sourceValues;
}

class ImportResult {
  const ImportResult({
    required this.attempted,
    required this.inserted,
    required this.failed,
    required this.failures,
  });

  final int attempted;
  final int inserted;
  final int failed;
  final List<ImportRowFailure> failures;

  ImportResult operator +(ImportResult other) => ImportResult(
    attempted: attempted + other.attempted,
    inserted: inserted + other.inserted,
    failed: failed + other.failed,
    failures: [...failures, ...other.failures],
  );

  static const empty = ImportResult(
    attempted: 0,
    inserted: 0,
    failed: 0,
    failures: [],
  );
}
