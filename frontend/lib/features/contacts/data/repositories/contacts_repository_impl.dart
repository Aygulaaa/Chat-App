import 'package:my_chat_app/features/contacts/data/datasources/contacts_remote_datasource.dart';
import 'package:my_chat_app/features/contacts/domain/entities/contact.dart';
import 'package:my_chat_app/features/contacts/domain/repositories/contacts_repository.dart';

class ContactsRepositoryImpl implements ContactsRepository {
  final ContactsRemoteDatasource remote;
  const ContactsRepositoryImpl(this.remote);

  @override
  Future<List<Contact>> getContacts() => remote.getContacts();

  @override
  Future<List<Contact>> getBlockedContacts() => remote.getBlockedContacts();

  @override
  Future<List<Contact>> searchUsers(String query) => remote.searchUsers(query);

  @override
  Future<void> addContact(int contactId) => remote.addContact(contactId);

  @override
  Future<void> removeContact(int contactId) => remote.removeContact(contactId);

  @override
  Future<void> blockUser(int contactId) => remote.blockUser(contactId);

  @override
  Future<void> unblockUser(int contactId) => remote.unblockUser(contactId);
}