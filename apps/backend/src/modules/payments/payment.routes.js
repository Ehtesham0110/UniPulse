import { Router } from 'express';
import { authenticate } from '../../middleware/auth.js';
import { createOrder, verifyPayment, failPayment } from './payment.controller.js';

export const paymentRouter = Router();

paymentRouter.use(authenticate);

paymentRouter.post('/orders', createOrder);
paymentRouter.post('/verify', verifyPayment);
paymentRouter.post('/:paymentId/fail', failPayment);
