import '../repositories/contacts_repository.dart';

class BlockUser {
  final ContactsRepository repository;
  const BlockUser(this.repository);
  Future<void> call(int contactId, {bool block = true}) =>
      block ? repository.blockUser(contactId) : repository.unblockUser(contactId);
}