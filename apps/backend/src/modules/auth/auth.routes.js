import { Router } from 'express';
import { firebaseLogin, refreshAccessToken, getCurrentUser } from './auth.controller.js';
import { authenticate } from '../../middleware/auth.js';

export const authRouter = Router();

authRouter.post('/firebase-login', firebaseLogin);
authRouter.post('/refresh', refreshAccessToken);
authRouter.get('/me', authenticate, getCurrentUser);
