import { Router } from 'express';
import { getCitiesByState, getStates } from '../../controllers/bangarProperties/bangarProperties_locationController.js';

const router = Router();

router.get('/locations/states', getStates);
router.get('/locations/cities', getCitiesByState);

export default router;

