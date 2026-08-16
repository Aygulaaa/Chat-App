import { Router } from 'express';
import { userController } from './user.controller';
import { auth } from "../../middleware/auth.middleware";
import multer from 'multer';

const upload = multer({ storage: multer.memoryStorage() });
const router = Router();

router.use(auth);

router.get('/user/:userId', userController.getUserById);
router.get('/me', userController.getMe);
router.put('/me', userController.updateMe);
router.post('/avatar', upload.single('avatar'), userController.updateAvatar);
router.post('/fcm-token', userController.pushNotification);

export default router;