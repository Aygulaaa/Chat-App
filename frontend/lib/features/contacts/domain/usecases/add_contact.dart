import 'package:my_chat_app/features/contacts/domain/repositories/contacts_repository.dart';

class AddContact {
  final ContactsRepository repository;
  const AddContact(this.repository);
  Future<void> call(int contactId) => repository.addContact(contactId);
}