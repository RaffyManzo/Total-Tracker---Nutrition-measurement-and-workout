import 'package:objectbox/objectbox.dart';

class OpenNutritionImportStatusCodes {
  const OpenNutritionImportStatusCodes._();
  static const String notInstalled = 'not_installed';
  static const String downloading = 'downloading';
  static const String verifying = 'verifying';
  static const String extracting = 'extracting';
  static const String validatingSchema = 'validating_schema';
  static const String converting = 'converting';
  static const String indexing = 'indexing';
  static const String activating = 'activating';
  static const String installed = 'installed';
  static const String cancelled = 'cancelled';
  static const String failed = 'failed';
}

@Entity()
class OpenNutritionCatalogStateEntity {
  OpenNutritionCatalogStateEntity({
    this.id = 0,
    this.installedVersion = '',
    this.activeBatchId = '',
    this.sourceArchiveUrl = '',
    this.expectedSha256 = '',
    this.actualSha256 = '',
    this.archiveBytes = 0,
    this.extractedBytes = 0,
    this.parsedRows = 0,
    this.importedRows = 0,
    this.skippedRows = 0,
    this.failedRows = 0,
    this.importStatusCode = OpenNutritionImportStatusCodes.notInstalled,
    this.currentStageCode = OpenNutritionImportStatusCodes.notInstalled,
    this.lastError = '',
    this.schemaJson = '{}',
    this.attributionVersion = '1',
    this.licenseAcceptedAtEpochMs,
    this.startedAtEpochMs,
    this.completedAtEpochMs,
  });

  @Id()
  int id;
  String installedVersion;
  String activeBatchId;
  String sourceArchiveUrl;
  String expectedSha256;
  String actualSha256;
  int archiveBytes;
  int extractedBytes;
  int parsedRows;
  int importedRows;
  int skippedRows;
  int failedRows;
  String importStatusCode;
  String currentStageCode;
  String lastError;
  String schemaJson;
  String attributionVersion;
  int? licenseAcceptedAtEpochMs;
  int? startedAtEpochMs;
  int? completedAtEpochMs;
}
