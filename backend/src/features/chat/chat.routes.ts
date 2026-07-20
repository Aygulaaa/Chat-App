import { Router } from 'express';
import { chatController } from '../chat/chat.controller';
import multer from 'multer';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB max
});

const router = Router();

router.get('/', chatController.getChats);

router.post('/group', chatController.createGroupChat);

router.post('/create/:contactId', chatController.createChat);

router.post('/:chatId/members', chatController.addMember);
router.delete('/:chatId/members/:userId', chatController.removeMember);

router.patch('/:chatId/group', chatController.updateGroupInfo);

router.get('/:chatId/messages', chatController.getMessages);

router.post('/:chatId/messages', chatController.sendMessage);

router.post(
  '/:chatId/messages/file',
  upload.single('file'),
  chatController.sendFileMessage
);

router.patch('/:chatId/messages/read', chatController.markMessagesRead);

router.get('/:chatId', chatController.getChat);

export default router;