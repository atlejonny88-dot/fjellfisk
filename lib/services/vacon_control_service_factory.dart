import 'vacon_api_control_service.dart';
import 'vacon_control_service.dart';

VaconControlService createVaconControlService() {
  const backendUrl = String.fromEnvironment('FJELLFISK_COLLECTOR_BACKEND_URL');
  return backendUrl.trim().isEmpty
      ? MockVaconControlService.shared
      : VaconApiControlService.fromEnvironment();
}
