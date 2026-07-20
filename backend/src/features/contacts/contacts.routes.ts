import { Router } from 'express';
import { contactsController } from './contacts.controller';
import { auth } from '../../middleware/auth.middleware';

const router = Router();

router.use(auth);

router.get('/', contactsController.getContacts);
router.get('/blocked', contactsController.getBlockedContacts);
router.get('/search', contactsController.searchUsers);
router.post('/:contactId', contactsController.addContact);
router.delete('/:contactId', contactsController.removeContact);
router.post('/:contactId/block', contactsController.blockUser);
router.delete('/:contactId/block', contactsController.unblockUser);

export default router;