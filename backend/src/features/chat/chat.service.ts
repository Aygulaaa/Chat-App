import { chatRepository } from '../chat/chat.repository';
import { v2 as cloudinary } from 'cloudinary';

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME!,
  api_key: process.env.CLOUDINARY_API_KEY!,
  api_secret: process.env.CLOUDINARY_API_SECRET!,
});

function getResourceType(mimeType: string): 'image' | 'video' | 'raw' | 'auto' {
  if (mimeType.startsWith('image/')) return 'image';
  if (mimeType.startsWith('video/')) return 'video';
  if (mimeType.startsWith('audio/')) return 'video';
  return 'raw';
}

function getFileType(mimeType: string): string {
  if (mimeType.startsWith('image/')) return 'image';
  if (mimeType.startsWith('video/')) return 'video';
  if (mimeType.startsWith('audio/')) return 'audio';
  if (mimeType === 'application/pdf') return 'pdf';
  if (mimeType.includes('zip') || mimeType.includes('compressed')) return 'archive';
  return 'file';
}


export const chatService = {
  async getChats(userId: number) {
    try {
      const result = await chatRepository.getChats(userId);
      return result.rows;
    } catch (err) {
      throw err;
    }
  },

  async getChat(chatId: number, userId: number) {
    try {
      const result = await chatRepository.getChat(chatId, userId);
      return result.rows[0];
    } catch (err) {
      throw err;
    }
  },

  async getMessages(chatId: number, userId: number) {
    try {
      const result = await chatRepository.getMessages(chatId, userId);
      return result.rows;
    } catch (err) {
      throw err;
    }
  },

  async createChat(userId: number, contactId: number) {
    try {
      const result = await chatRepository.createChat(userId, contactId);
      return result;
    } catch (err) {
      throw err;
    }
  },

  async sendMessage(chatId: number, senderId: number, text: string) {
    try {
      const result = await chatRepository.sendMessage(chatId, senderId, text);
      return result.rows[0];
    } catch (err) {
      throw err;
    }
  },

  async markMessagesDelivered(chatId: number, recipientId: number) {
    try {
      const result = await chatRepository.markMessagesDelivered(chatId, recipientId);
      return result.rows;
    } catch (err) {
      throw err;
    }
  },

  async markMessagesRead(chatId: number, readerId: number) {
    try {
      const result = await chatRepository.markMessagesRead(chatId, readerId);
      return result.rows;
    } catch (err) {
      throw err;
    }
  },

  async sendFileMessage(
    chatId: number,
    senderId: number,
    fileBuffer: Buffer,
    originalName: string,
    mimeType: string,
    fileSize: number,
  ) {

    const resourceType = getResourceType(mimeType);
    const fileType = getFileType(mimeType);

    const fileUrl = await new Promise<string>((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        {
          folder: 'chat_files',
          resource_type: resourceType,
          public_id: `${Date.now()}_${originalName.replace(/\s+/g, '_')}`,
          use_filename: true,
          unique_filename: false,
        },
        (error, result) => {
          if (error) return reject(error);
          resolve(result!.secure_url);
        }
      );
      stream.end(fileBuffer);
    });

    const result = await chatRepository.sendFileMessage(
      chatId,
      senderId,
      fileUrl,
      fileType,
      originalName,
      mimeType,
      fileSize,
    );

    return result.rows[0];
  },

  async createGroupChat(creatorId: number, name: string, memberIds: number[], avatar?: string) {
    const result = await chatRepository.createGroupChat(creatorId, name, memberIds, avatar);
    return result;
  },

  async addMember(chatId: number, userId: number) {
    const result = await chatRepository.addMemberToGroup(chatId, userId);
    return result.rows[0];
  },

  async removeMember(chatId: number, userId: number) {
    const result = await chatRepository.removeMemberFromGroup(chatId, userId);
    return result.rows[0];
  },

  async uploadGroupAvatar(fileBuffer: Buffer, originalName: string, mimeType: string) {
    const resourceType = getResourceType(mimeType);

    const fileUrl = await new Promise<string>((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        {
          folder: 'group_avatars',
          resource_type: resourceType,
          public_id: `${Date.now()}_${originalName.replace(/\\s+/g, '_')}`,
          use_filename: true,
          unique_filename: false,
        },
        (error, result) => {
          if (error) return reject(error);
          resolve(result!.secure_url);
        }
      );
      stream.end(fileBuffer);
    });

    return fileUrl;
  },

  async updateGroupInfo(chatId: number, name?: string, avatar?: string) {
    const result = await chatRepository.updateGroupInfo(chatId, name, avatar);
    return result.rows[0];
  },

  async deleteChat(chatId: number) {
    const result = await chatRepository.deleteChat(chatId);
    return result.rows[0];
  },

  async deleteGroup(chatId: number, requesterId: number) {
    return await chatRepository.deleteGroup(chatId, requesterId);
  },
}