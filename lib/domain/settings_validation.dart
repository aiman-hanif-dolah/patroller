import '../models/app_settings.dart';
import '../widgets/panel_resize_handle.dart';

class SettingsFieldError {
  const SettingsFieldError(this.field, this.message);

  final String field;
  final String message;
}

int? parsePositiveInt(String value, {required int min, required int max}) {
  final parsed = int.tryParse(value.trim());
  if (parsed == null) return null;
  if (parsed < min || parsed > max) return null;
  return parsed;
}

List<SettingsFieldError> validateAppSettings(AppSettings settings) {
  final errors = <SettingsFieldError>[];

  void requirePath(String field, String value) {
    if (value.trim().isEmpty) {
      errors.add(SettingsFieldError(field, 'Path cannot be empty.'));
    }
  }

  requirePath('patrolPath', settings.patrolPath);
  requirePath('flutterPath', settings.flutterPath);
  requirePath('dartPath', settings.dartPath);
  requirePath('xcrunPath', settings.xcrunPath);

  if (settings.testDirectory.trim().isEmpty) {
    errors.add(const SettingsFieldError(
      'testDirectory',
      'Test directory is required.',
    ));
  }

  if (settings.logRetentionCount < 10 || settings.logRetentionCount > 1000) {
    errors.add(const SettingsFieldError(
      'logRetentionCount',
      'Retention must be between 10 and 1000.',
    ));
  }

  if (settings.rightPanelWidth < rightPanelMinWidth ||
      settings.rightPanelWidth > rightPanelMaxWidth) {
    errors.add(SettingsFieldError(
      'rightPanelWidth',
      'Right panel width must be $rightPanelMinWidth–$rightPanelMaxWidth.',
    ));
  }

  if (settings.logsPanelWidth < logsPanelMinWidth ||
      settings.logsPanelWidth > logsPanelMaxWidth) {
    errors.add(SettingsFieldError(
      'logsPanelWidth',
      'Logs panel width must be $logsPanelMinWidth–$logsPanelMaxWidth.',
    ));
  }

  return errors;
}