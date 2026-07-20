import 'package:my_chat_app/core/constants/api_endpoints.dart';
import 'package:my_chat_app/core/network/api_client.dart';
import '../models/contact_model.dart';

class ContactsRemoteDatasource {
  final ApiClient api;
  const ContactsRemoteDatasource(this.api);

  Future<List<ContactModel>> getContacts() async {
    final data = await api.get(ApiEndpoints.contacts);
    return (data as List).map((e) => ContactModel.fromJson(e)).toList();
  }

  Future<List<ContactModel>> getBlockedContacts() async {
    final data = await api.get(ApiEndpoints.blocked);
    return (data as List).map((e) => ContactModel.fromJson(e)).toList();
  }

  Future<List<ContactModel>> searchUsers(String query) async {
    final data = await api.get(ApiEndpoints.search(query));
    return (data as List).map((e) => ContactModel.fromJson(e)).toList();
  }

  Future<void> addContact(int contactId) async {
    await api.post(ApiEndpoints.contactAction(contactId), null);
  }

  Future<void> removeContact(int contactId) async {
    await api.delete(ApiEndpoints.contactAction(contactId));
  }

  Future<void> blockUser(int contactId) async {
    await api.post(ApiEndpoints.blockAction(contactId), null);
  }

  Future<void> unblockUser(int contactId) async {
    await api.delete(ApiEndpoints.blockAction(contactId));
  }
}