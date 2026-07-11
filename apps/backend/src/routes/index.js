import { Router } from 'express';
import { authRouter } from '../modules/auth/auth.routes.js';
import { analyticsRouter } from '../modules/analytics/analytics.routes.js';
import { clubRouter } from '../modules/clubs/club.routes.js';
import { collegeRouter } from '../modules/colleges/college.routes.js';
import { eventRouter } from '../modules/events/event.routes.js';
import { registrationRouter } from '../modules/registrations/registration.routes.js';
import { paymentRouter } from '../modules/payments/payment.routes.js';
import { attendanceRouter } from '../modules/attendance/attendance.routes.js';
import { certificateRouter } from '../modules/certificates/certificate.routes.js';

export const apiRouter = Router();

apiRouter.use('/auth', authRouter);
apiRouter.use('/analytics', analyticsRouter);
apiRouter.use('/clubs', clubRouter);
apiRouter.use('/colleges', collegeRouter);
apiRouter.use('/events', eventRouter);
apiRouter.use('/registrations', registrationRouter);
apiRouter.use('/payments', paymentRouter);
apiRouter.use('/attendance', attendanceRouter);
apiRouter.use('/certificates', certificateRouter);

