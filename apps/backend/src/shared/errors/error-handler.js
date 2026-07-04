import { ApiError } from './api-error.js';

export function notFoundHandler(req, _res, next) {
  next(new ApiError(404, `Route not found: ${req.method} ${req.originalUrl}`));
}

export function errorHandler(error, _req, res, _next) {
  const statusCode = error instanceof ApiError ? error.statusCode : 500;
  res.status(statusCode).json({
    success: false,
    message: error.message ?? 'Internal server error',
    details: error.details,
  });
}

