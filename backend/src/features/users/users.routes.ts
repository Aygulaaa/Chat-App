import { Router } from 'express';
import { userController } from './user.controller';
import { auth } from "../../middleware/auth.middleware";
import multer from 'multer';

// Without limits multer buffers an upload of ANY size into RAM
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024, files: 1 },
  fileFilter: (_req, file, cb) => cb(null, file.mimetype.startsWith('image/')),
});
const router = Router();

router.use(auth);

router.get('/user/:userId', userController.getUserById);
router.get('/me', userController.getMe);
router.put('/me', userController.updateMe);
router.post('/avatar', upload.single('avatar'), userController.updateAvatar);
router.post('/fcm-token', userController.pushNotification);
router.delete('/fcm-token', userController.clearPushToken);

export default router;