import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { ApiError } from '../shared/errors/api-error.js';
import { User } from '../modules/users/user.model.js';

export async function authenticate(req, _res, next) {
  try {
    const header = req.headers.authorization;
    // External viewers (a browser tab / PDF app opened via url_launcher
    // for certificate view/download) can't attach an Authorization
    // header, so a `?token=` query param is accepted as a fallback ONLY
    // when no Bearer header is present. This never weakens the Bearer
    // path — it's purely additive for the certificate PDF endpoints.
    const queryToken = typeof req.query?.token === 'string' ? req.query.token : null;
    const token = header?.startsWith('Bearer ') ? header.slice('Bearer '.length) : queryToken;

    if (!token) {
      throw new ApiError(401, 'Authentication token is required');
    }

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

