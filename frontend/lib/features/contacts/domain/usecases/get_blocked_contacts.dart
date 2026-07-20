import '../entities/contact.dart';
import '../repositories/contacts_repository.dart';

class GetBlockedContacts {
  final ContactsRepository repository;
  const GetBlockedContacts(this.repository);
  Future<List<Contact>> call() => repository.getBlockedContacts();
}