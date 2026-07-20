import { Router } from 'express';
import { propertyHandlers } from '../../controllers/mahaProperties/mahaProperties_propertyController.js';

const router = Router();
const {
  createProperty,
  getProperties,
  getPropertyById,
  updateProperty,
  deleteProperty,
} = propertyHandlers;

router.get('/properties', getProperties);
router.post('/properties', createProperty);
router.get('/properties/:id', getPropertyById);
router.put('/properties/:id', updateProperty);
router.delete('/properties/:id', deleteProperty);

export default router;
