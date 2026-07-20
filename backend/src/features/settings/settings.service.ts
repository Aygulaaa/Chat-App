import { settingsRepository } from './settings.repository';

export const settingsService = {
  async getSettings(userId: number) {
    return settingsRepository.getSettings(userId);
  },

  async updateSettings(userId: number, updates: any) {
    await settingsRepository.createDefaults(userId);
    return settingsRepository.updateSettings(userId, updates);
  },
};