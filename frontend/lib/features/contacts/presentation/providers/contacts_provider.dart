import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/contacts/data/datasources/contacts_remote_datasource.dart';
import 'package:my_chat_app/features/contacts/data/repositories/contacts_repository_impl.dart';
import 'package:my_chat_app/features/contacts/domain/entities/contact.dart';
import 'package:my_chat_app/features/contacts/domain/repositories/contacts_repository.dart';
import 'package:my_chat_app/features/contacts/domain/usecases/add_contact.dart';
import 'package:my_chat_app/features/contacts/domain/usecases/block_user.dart';
import 'package:my_chat_app/features/contacts/domain/usecases/get_blocked_contacts.dart';
import 'package:my_chat_app/features/contacts/domain/usecases/get_contacts.dart';
import 'package:my_chat_app/features/contacts/domain/usecases/remove_contact.dart';
import 'package:my_chat_app/features/contacts/domain/usecases/search_users.dart';

// ─── Infrastructure providers ─────────────────────────────────────────────────

final contactsDatasourceProvider = Provider(
  (ref) => ContactsRemoteDatasource(ref.read(apiClientProvider)),
);

final contactsRepositoryProvider = Provider<ContactsRepository>(
  (ref) => ContactsRepositoryImpl(ref.read(contactsDatasourceProvider)),
);

// ─── Contacts list ────────────────────────────────────────────────────────────

final contactsProvider = AsyncNotifierProvider<ContactsNotifier, List<Contact>>(
  ContactsNotifier.new,
);

class ContactsNotifier extends AsyncNotifier<List<Contact>> {
  GetContacts? _getContacts;

  @override
  Future<List<Contact>> build() async {
    final auth = ref.watch(authProvider);

    if (auth.isLoading) {
      throw Exception("Auth loading");
    }

    final repo = ref.read(contactsRepositoryProvider);
    _getContacts = GetContacts(repo);

    return await _getContacts!();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _getContacts!());
  }

  Future<void> addContact(int contactId) async {
    final repo = ref.read(contactsRepositoryProvider);
    await AddContact(repo)(contactId);
    ref.invalidateSelf();
    ref.invalidate(blockedContactsProvider);
    ref.invalidate(searchUsersProvider);
  }

  Future<void> removeContact(int contactId) async {
    final repo = ref.read(contactsRepositoryProvider);
    await RemoveContact(repo)(contactId);
    ref.invalidateSelf();
    ref.invalidate(searchUsersProvider);
  }

  Future<void> blockUser(int contactId) async {
    final repo = ref.read(contactsRepositoryProvider);
    await BlockUser(repo)(contactId, block: true);
    ref.invalidateSelf();
    ref.invalidate(blockedContactsProvider);
    ref.invalidate(searchUsersProvider);
  }

  Future<void> unblockUser(int contactId) async {
    final repo = ref.read(contactsRepositoryProvider);
    await BlockUser(repo)(contactId, block: false);
    ref.invalidateSelf();
    ref.invalidate(blockedContactsProvider);
  }
}

// ─── Blocked contacts ─────────────────────────────────────────────────────────

final blockedContactsProvider =
    AsyncNotifierProvider<BlockedContactsNotifier, List<Contact>>(
      BlockedContactsNotifier.new,
    );

class BlockedContactsNotifier extends AsyncNotifier<List<Contact>> {
  GetBlockedContacts? _getBlocked;

  @override
  Future<List<Contact>> build() async {
    final repo = ref.read(contactsRepositoryProvider);
    _getBlocked = GetBlockedContacts(repo);
    return _fetchData();
  }

  Future<List<Contact>> _fetchData() async {
    return await _getBlocked!();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchData());
  }

  Future<void> unblock(int contactId) async {
  final repo = ref.read(contactsRepositoryProvider);
  
  // Set state to loading so the UI shows activity
  state = const AsyncValue.loading();
  
  try {
    await BlockUser(repo)(contactId, block: false);
    
    final newList = await _getBlocked!();
    state = AsyncValue.data(newList);
    
    ref.invalidate(contactsProvider);
    ref.invalidate(searchUsersProvider);
  } catch (e, st) {
    state = AsyncValue.error(e, st);
  }
}
}

final searchUsersProvider =
    AsyncNotifierProvider.family<SearchNotifier, List<Contact>, String>(
      SearchNotifier.new,
    );

class SearchNotifier extends FamilyAsyncNotifier<List<Contact>, String> {
  @override
  Future<List<Contact>> build(String query) async {
    if (query.trim().isEmpty) return [];

    final searchUsers = SearchUsers(ref.read(contactsRepositoryProvider));
    await Future.delayed(const Duration(milliseconds: 300));

    return await searchUsers(query.trim());
  }
}
