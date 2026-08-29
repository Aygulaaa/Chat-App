import { chatRepository } from '../chat/chat.repository';
import { v2 as cloudinary } from 'cloudinary';

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME!,
  api_key: process.env.CLOUDINARY_API_KEY!,
  api_secret: process.env.CLOUDINARY_API_SECRET!,
});

function getResourceType(mimeType: string): 'image' | 'video' | 'raw' {
  if (mimeType.startsWith('image/')) return 'image';
  if (mimeType.startsWith('video/') || mimeType.startsWith('audio/')) return 'video';
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

async function uploadToCloudinary(
  fileBuffer: Buffer,
  folder: string,
  originalName: string,
  mimeType: string
): Promise<string> {
  const resourceType = getResourceType(mimeType);
  const cleanFileName = originalName.replace(/[^a-zA-Z0-9_.-]/g, '_');

  return new Promise<string>((resolve, reject) => {
    const uploadOptions: Record<string, any> = {
      folder,
      resource_type: resourceType,
      public_id: `${Date.now()}_${cleanFileName}`,
      use_filename: true,
      unique_filename: false,
    };

    if (resourceType === 'raw') {
      uploadOptions.format = originalName.split('.').pop();
    }

    const stream = cloudinary.uploader.upload_stream(uploadOptions, (error, result) => {
      if (error) return reject(new Error(`Cloudinary Upload Failed: ${error.message}`));
      if (!result?.secure_url) return reject(new Error('Cloudinary failed to return URL'));
      resolve(result.secure_url);
    });

    stream.on('error', (err) => reject(new Error(`Upload stream error: ${err.message}`)));
    stream.end(fileBuffer);
  });
}

export const chatService = {
  async getChats(userId: number) {
    return await chatRepository.getChats(userId);
  },

  async getChat(chatId: number, userId: number) {
    const chat = await chatRepository.getChat(chatId, userId);
    if (!chat) {
      throw new Error('Chat not found or access denied');
    }
    return chat;
  },

  async getMessages(chatId: number, userId: number, limit = 50, beforeId?: number) {
    return await chatRepository.getMessages(chatId, userId, limit, beforeId);
  },

  async createChat(userId: number, contactId: number) {
    if (userId === contactId) {
      throw new Error('Cannot create a chat with yourself');
    }
    return await chatRepository.createChat(userId, contactId);
  },

  async sendMessage(chatId: number, senderId: number, text: string) {
    const message = await chatRepository.sendMessage(chatId, senderId, text);
    if (!message) {
      throw new Error('Access denied: You are not a member of this chat');
    }
    return message;
  },

  async markMessagesDelivered(chatId: number, recipientId: number) {
    return await chatRepository.markMessagesDelivered(chatId, recipientId);
  },

  async markMessagesRead(chatId: number, readerId: number) {
    return await chatRepository.markMessagesRead(chatId, readerId);
  },

  async sendFileMessage(
    chatId: number,
    senderId: number,
    fileBuffer: Buffer,
    originalName: string,
    mimeType: string,
    fileSize: number
  ) {
    const fileType = getFileType(mimeType);

    // Upload to Cloudinary after validation
    const fileUrl = await uploadToCloudinary(fileBuffer, 'chat_files', originalName, mimeType);

    const message = await chatRepository.sendFileMessage(
      chatId,
      senderId,
      fileUrl,
      fileType,
      originalName,
      mimeType,
      fileSize
    );

    if (!message) {
      throw new Error('Access denied: You are not a member of this chat');
    }

    return message;
  },

  async createGroupChat(creatorId: number, name: string, memberIds: number[], avatar?: string) {
    const uniqueMembers = Array.from(new Set([...memberIds, creatorId]));
    return await chatRepository.createGroupChat(creatorId, name, uniqueMembers, avatar);
  },

  async addMember(chatId: number, userId: number) {
    return await chatRepository.addMemberToGroup(chatId, userId);
  },

  async removeMember(chatId: number, userId: number) {
    return await chatRepository.removeMemberFromGroup(chatId, userId);
  },

  async uploadGroupAvatar(fileBuffer: Buffer, originalName: string, mimeType: string) {
    if (!mimeType.startsWith('image/')) {
      throw new Error('Group avatar must be an image file');
    }
    return await uploadToCloudinary(fileBuffer, 'group_avatars', originalName, mimeType);
  },

  async updateGroupInfo(chatId: number, name?: string, avatar?: string) {
    return await chatRepository.updateGroupInfo(chatId, name, avatar);
  },

  async deleteMessage(messageId: number, senderId: number) {
    return await chatRepository.deleteMessage(messageId, senderId);
  },

  async deleteChat(chatId: number) {
    return await chatRepository.deleteChat(chatId);
  },

  async deleteGroup(chatId: number, requesterId: number) {
    return await chatRepository.deleteGroup(chatId, requesterId);
  },
};