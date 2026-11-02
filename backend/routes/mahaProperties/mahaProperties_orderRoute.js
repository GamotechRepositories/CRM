import { Router } from 'express';
import {
  createOrder,
  getOrders,
  getOrderById,
  updateOrder,
  deleteOrder,
  getOrderTracking,
} from '../../controllers/mahaProperties/mahaProperties_orderController.js';

const router = Router();

router.get('/order', getOrders);
router.get('/order/tracking/:clientId', getOrderTracking);
router.post('/order', createOrder);
router.get('/order/:id', getOrderById);
router.put('/order/:id', updateOrder);
router.delete('/order/:id', deleteOrder);

export default router;
