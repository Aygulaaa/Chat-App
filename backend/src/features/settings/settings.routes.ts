import { Router } from 'express';
import { settingsController } from './settings.controller';
import { auth } from '../../middleware/auth.middleware';

const router = Router();
router.use(auth);

router.get('/', settingsController.getSettings);
router.patch('/', settingsController.updateSettings);

export default router;