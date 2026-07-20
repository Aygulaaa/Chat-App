import '../repositories/contacts_repository.dart';

class RemoveContact {
  final ContactsRepository repository;
  const RemoveContact(this.repository);
  Future<void> call(int contactId) => repository.removeContact(contactId);
}