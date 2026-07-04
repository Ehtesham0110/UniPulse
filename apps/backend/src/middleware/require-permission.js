import { ApiError } from '../shared/errors/api-error.js';
import { roleHasPermission } from '../shared/utils/roles.js';

export function requirePermission(permission) {
  return (req, _res, next) => {
    if (!req.user || !roleHasPermission(req.user.role, permission)) {
      return next(new ApiError(403, 'You do not have permission to perform this action'));
    }
    return next();
  };
}

