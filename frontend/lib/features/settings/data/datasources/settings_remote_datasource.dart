import 'package:my_chat_app/core/constants/api_endpoints.dart';
import 'package:my_chat_app/core/network/api_client.dart';
import 'package:my_chat_app/features/settings/data/models/settings_model.dart';

class SettingsRemoteDatasource {
  final ApiClient api;
  const SettingsRemoteDatasource(this.api);

  Future<SettingsModel> getSettings() async {
    final data= await api.get(ApiEndpoints.settings);
    return SettingsModel.fromJson(data);
  }

  Future<SettingsModel> updateSettings(Map<String, dynamic> updates) async {
    final data= await api.patch(ApiEndpoints.settings, updates);
    return SettingsModel.fromJson(data);
  }
}