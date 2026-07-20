import { contactsRepository } from './contacts.repository';

export const contactsService = {
  async getContacts(userId: number) {
    const result = await contactsRepository.getContacts(userId);
    return result.rows;
  },

  async getBlockedContacts(userId: number) {
    const result = await contactsRepository.getBlockedContacts(userId);
    return result.rows;
  },

  async searchUsers(query: string, userId: number) {
    if (!query.trim()) return [];
    const result = await contactsRepository.searchUsers(query, userId);
    return result.rows;
  },

  async addContact(userId: number, contactId: number) {
    if (userId === contactId) throw new Error('Cannot add yourself');
    const result = await contactsRepository.addContact(userId, contactId);
    return result.rows[0];
  },

  async removeContact(userId: number, contactId: number) {
    const result = await contactsRepository.removeContact(userId, contactId);
    return result.rows[0];
  },

  async blockUser(userId: number, contactId: number) {
    if (userId === contactId) throw new Error('Cannot block yourself');
    const result = await contactsRepository.blockUser(userId, contactId);
    return result.rows[0];
  },

  async unblockUser(userId: number, contactId: number) {
    const result = await contactsRepository.unblockUser(userId, contactId);
    return result.rows[0];
  },
};