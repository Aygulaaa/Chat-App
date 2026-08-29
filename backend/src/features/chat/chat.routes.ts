import { Router } from 'express';
import { chatController } from '../chat/chat.controller';
import { validateNumericParams } from '../../middleware/validateParams';
import multer from 'multer';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB max
});

const router = Router();

// Reusable middleware instances for chat routes
const validateChatId = validateNumericParams('chatId');
const validateChatAndMessage = validateNumericParams('chatId', 'messageId');
const validateChatAndUser = validateNumericParams('chatId', 'userId');
const validateContactId = validateNumericParams('contactId');

// 1. Static routes
router.get('/', chatController.getChats);
router.post('/group', chatController.createGroupChat);
router.post('/create/:contactId', validateContactId, chatController.createChat);

// 2. Dynamic routes
router.get('/:chatId', validateChatId, chatController.getChat);
router.get('/:chatId/messages', validateChatId, chatController.getMessages);
router.post('/:chatId/messages', validateChatId, chatController.sendMessage);
router.patch('/:chatId/messages/read', validateChatId, chatController.markMessagesRead);

router.post(
  '/:chatId/messages/file',
  validateChatId,
  upload.single('file'),
  chatController.sendFileMessage
);

router.post('/:chatId/members', validateChatId, chatController.addMember);
router.delete('/:chatId/members/:userId', validateChatAndUser, chatController.removeMember);
router.patch('/:chatId/group', validateChatId, upload.single('avatar'), chatController.updateGroupInfo);
router.delete('/:chatId/messages/:messageId', validateChatAndMessage, chatController.deleteMessage);
router.delete('/:chatId/group', validateChatId, chatController.deleteGroup);
router.delete('/:chatId', validateChatId, chatController.deleteChat);

export default router;