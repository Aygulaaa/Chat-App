import { Router } from 'express';
import { contactsController } from './contacts.controller';
import { auth } from '../../middleware/auth.middleware';
import { validateNumericParams } from '../../middleware/validateParams';

const router = Router();

router.use(auth);

// 'abc' → NaN → a raw Postgres error without this
const validateContactId = validateNumericParams('contactId');

router.get('/', contactsController.getContacts);
router.get('/blocked', contactsController.getBlockedContacts);
router.get('/search', contactsController.searchUsers);
router.post('/:contactId', validateContactId, contactsController.addContact);
router.delete('/:contactId', validateContactId, contactsController.removeContact);
router.post('/:contactId/block', validateContactId, contactsController.blockUser);
router.delete('/:contactId/block', validateContactId, contactsController.unblockUser);

export default router;