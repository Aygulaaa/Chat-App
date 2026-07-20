import { userRepository } from './users.repository';
import { v2 as cloudinary } from 'cloudinary';

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME!,
  api_key: process.env.CLOUDINARY_API_KEY!,
  api_secret: process.env.CLOUDINARY_API_SECRET!,
});

export const userService = {
  async getProfile(userId: number) {
    const result = await userRepository.getUserById(userId);
    return result.rows[0];
  },

  async updateProfile(userId: number, username: string, bio: string, birthDate: string) {
    const result = await userRepository.updateProfile(userId, username, bio, birthDate);
    return result.rows[0];
  },

  async updateAvatar(userId: number, avatarUrl: string) {
    const result = await userRepository.updateAvatar(userId, avatarUrl);
    return result.rows[0];
  },

  async uploadToCloudinary(fileBuffer: Buffer): Promise<string> {
    return new Promise((resolve, reject) => {
      const uploadStream = cloudinary.uploader.upload_stream(
        { folder: 'chat_avatars' },
        (error, result) => {
          if (error) return reject(error);
          resolve(result!.secure_url);
        }
      );
      uploadStream.end(fileBuffer);
    });
  },

  async updateLastSeen(userId: number) {
    const result = await userRepository.updateLastSeen(userId);
    return result.rows[0];
  },
};