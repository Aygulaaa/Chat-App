import 'package:my_chat_app/features/contacts/domain/entities/contact.dart';

abstract class ContactsRepository {
  Future<List<Contact>> getContacts();
  Future<List<Contact>> getBlockedContacts();
  Future<List<Contact>> searchUsers(String query);
  Future<void> addContact(int contactId);
  Future<void> removeContact(int contactId);
  Future<void> blockUser(int contactId);
  Future<void> unblockUser(int contactId);
}
