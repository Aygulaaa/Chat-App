import '../entities/contact.dart';
import '../repositories/contacts_repository.dart';

class GetContacts {
  final ContactsRepository repository;
  const GetContacts(this.repository);
  Future<List<Contact>> call() => repository.getContacts();
}