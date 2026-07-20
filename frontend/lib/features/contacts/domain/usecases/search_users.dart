import '../entities/contact.dart';
import '../repositories/contacts_repository.dart';

class SearchUsers {
  final ContactsRepository repository;
  const SearchUsers(this.repository);
  Future<List<Contact>> call(String query) => repository.searchUsers(query);
}