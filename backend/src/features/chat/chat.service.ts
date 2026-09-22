import { chatRepository, ChatError } from '../chat/chat.repository';
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
      throw new ChatError(404, 'Chat not found');
    }
    return chat;
  },

  async getMessages(chatId: number, userId: number, limit = 50, beforeId?: number) {
    return await chatRepository.getMessages(chatId, userId, limit, beforeId);
  },

  async getMessageById(messageId: number, userId: number) {
    return await chatRepository.getMessageById(messageId, userId);
  },

  async createChat(userId: number, contactId: number) {
    if (userId === contactId) {
      throw new ChatError(400, 'Cannot create a chat with yourself');
    }
    return await chatRepository.createChat(userId, contactId);
  },

  async sendMessage(chatId: number, senderId: number, text: string, replyToId?: number | null) {
    const message = await chatRepository.sendMessage(chatId, senderId, text, replyToId);
    if (!message) {
      throw new ChatError(403, 'Access denied: You are not a member of this chat');
    }
    return message;
  },

  async sendFileMessage(
    chatId: number,
    senderId: number,
    fileBuffer: Buffer,
    originalName: string,
    mimeType: string,
    fileSize: number,
    replyToId?: number | null
  ) {
    // Check membership BEFORE uploading, otherwise anyone can fill the
    // Cloudinary account by posting files at chats they don't belong to.
    if (!(await chatRepository.isMember(chatId, senderId))) {
      throw new ChatError(403, 'Access denied: You are not a member of this chat');
    }

    const fileType = getFileType(mimeType);

    const fileUrl = await uploadToCloudinary(fileBuffer, 'chat_files', originalName, mimeType);

    const message = await chatRepository.sendFileMessage(
      chatId,
      senderId,
      fileUrl,
      fileType,
      originalName,
      mimeType,
      fileSize,
      replyToId
    );

    if (!message) {
      throw new ChatError(403, 'Access denied: You are not a member of this chat');
    }

    return message;
  },

  async createGroupChat(creatorId: number, name: string, memberIds: number[], avatar?: string | null) {
    const uniqueMembers = Array.from(new Set(memberIds)).filter((id) => id !== creatorId);
    return await chatRepository.createGroupChat(creatorId, name, uniqueMembers, avatar);
  },

  async addMember(chatId: number, requesterId: number, userId: number) {
    return await chatRepository.addMemberToGroup(chatId, requesterId, userId);
  },

  async removeMember(chatId: number, requesterId: number, userId: number) {
    return await chatRepository.removeMemberFromGroup(chatId, requesterId, userId);
  },

  async uploadGroupAvatar(fileBuffer: Buffer, originalName: string, mimeType: string) {
    if (!mimeType.startsWith('image/')) {
      throw new ChatError(400, 'Group avatar must be an image file');
    }
    return await uploadToCloudinary(fileBuffer, 'group_avatars', originalName, mimeType);
  },

  async updateGroupInfo(chatId: number, requesterId: number, name?: string, avatar?: string) {
    return await chatRepository.updateGroupInfo(chatId, requesterId, name, avatar);
  },

  async isMember(chatId: number, userId: number) {
    return await chatRepository.isMember(chatId, userId);
  },

  /** One emoji per person per message; sending the same one again clears it. */
  async setReaction(messageId: number, userId: number, emoji: string) {
    // Emoji are 1–2 code points (plus skin tone / ZWJ sequences). A cap keeps
    // someone from storing a paragraph in the reaction pill.
    const clean = emoji.trim();
    if (!clean || [...clean].length > 8 || clean.length > 16) {
      throw new ChatError(400, 'Invalid reaction');
    }

    const result = await chatRepository.setReaction(messageId, userId, clean);
    if (!result) {
      throw new ChatError(404, 'Message not found');
    }
    return result;
  },

  async deleteMessage(messageId: number, senderId: number) {
    return await chatRepository.deleteMessage(messageId, senderId);
  },

  async deleteChat(chatId: number, requesterId: number) {
    return await chatRepository.deleteChat(chatId, requesterId);
  },

  async deleteGroup(chatId: number, requesterId: number) {
    return await chatRepository.deleteGroup(chatId, requesterId);
  },
};