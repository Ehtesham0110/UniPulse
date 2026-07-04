import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { ApiError } from '../shared/errors/api-error.js';
import { User } from '../modules/users/user.model.js';

export async function authenticate(req, _res, next) {
  try {
    const header = req.headers.authorization;
    if (!header?.startsWith('Bearer ')) {
      throw new ApiError(401, 'Authentication token is required');
    }

    const token = header.slice('Bearer '.length);
    const payload = jwt.verify(token, env.jwtAccessSecret);
    const user = await User.findById(payload.sub).select('-__v');

    if (!user || user.status !== 'Active') {
      throw new ApiError(401, 'Invalid or inactive user');
    }

    req.user = user;
    req.collegeId = user.collegeId;
    next();
  } catch (error) {
    next(error instanceof ApiError ? error : new ApiError(401, 'Invalid authentication token'));
  }
}

