import jwt from 'jsonwebtoken';
import { env } from '../../config/env.js';
import { verifyFirebaseIdToken } from '../../config/firebase.js';
import { asyncHandler } from '../../shared/utils/async-handler.js';
import { User } from '../users/user.model.js';
import { College } from '../colleges/college.model.js';
import { ApiError } from '../../shared/errors/api-error.js';

function issueTokens(user) {
  const payload = {
    sub: user._id.toString(),
    collegeId: user.collegeId.toString(),
    role: user.role,
  };
  return {
    accessToken: jwt.sign(payload, env.jwtAccessSecret, { expiresIn: env.jwtAccessExpiry }),
    refreshToken: jwt.sign({ sub: payload.sub }, env.jwtRefreshSecret, {
      expiresIn: env.jwtRefreshExpiry,
    }),
  };
}

/**
 * Phone-number login/signup.
 *
 * The client authenticates with Firebase (phone number + OTP) on-device,
 * then sends us the resulting Firebase ID token. We verify that token with
 * the Firebase Admin SDK and use the *verified* phone_number claim to find
 * or create the user. We never trust a phone number supplied directly in
 * the request body — that would let anyone log in as anyone else.
 */
export const firebaseLogin = asyncHandler(async (req, res) => {
  const { idToken, collegeCode, fullName, rollNumber, branch, year } = req.body;

  if (!idToken || !collegeCode) {
    throw new ApiError(400, 'idToken and collegeCode are required');
  }

  let decodedToken;
  try {
    decodedToken = await verifyFirebaseIdToken(idToken);
  } catch (error) {
    throw new ApiError(401, 'Invalid or expired Firebase ID token');
  }

  const phone = decodedToken.phone_number;
  if (!phone) {
    throw new ApiError(401, 'Firebase token does not contain a verified phone number');
  }

  const college = await College.findOne({ code: collegeCode.toUpperCase(), status: 'Active' });
  if (!college) {
    throw new ApiError(404, 'College not found or inactive');
  }

  let user = await User.findOne({ collegeId: college._id, phone });
  let isNewUser = false;

  if (!user) {
    if (!fullName || !rollNumber || !branch || !year) {
      throw new ApiError(422, 'Signup details are required for new users', {
        reason: 'SIGNUP_REQUIRED',
      });
    }
    user = await User.create({
      collegeId: college._id,
      fullName,
      phone,
      rollNumber,
      branch,
      year,
    });
    isNewUser = true;
  }

  if (user.status !== 'Active') {
    throw new ApiError(403, 'This account has been suspended. Contact your college admin.');
  }

  user.lastActiveAt = new Date();
  await user.save();

  res.json({
    success: true,
    data: {
      user,
      college,
      isNewUser,
      tokens: issueTokens(user),
    },
  });
});

/**
 * Exchanges a valid refresh token for a new access token, without
 * requiring the user to re-verify OTP. Used for silent/auto login.
 */
export const refreshAccessToken = asyncHandler(async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) {
    throw new ApiError(400, 'refreshToken is required');
  }

  let payload;
  try {
    payload = jwt.verify(refreshToken, env.jwtRefreshSecret);
  } catch (error) {
    throw new ApiError(401, 'Invalid or expired refresh token');
  }

  const user = await User.findById(payload.sub);
  if (!user || user.status !== 'Active') {
    throw new ApiError(401, 'Invalid or inactive user');
  }

  res.json({
    success: true,
    data: { tokens: issueTokens(user) },
  });
});

/**
 * Returns the currently authenticated user, including role — used by the
 * Flutter app on startup (auto login) to decide where to route the user
 * without asking them to log in again.
 */
export const getCurrentUser = asyncHandler(async (req, res) => {
  const college = await College.findById(req.user.collegeId);
  res.json({
    success: true,
    data: { user: req.user, college },
  });
});
