require('dotenv').config();

const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');
const crypto = require('crypto');

const app = express();
app.use(express.json());
app.use(
  cors({
    origin: process.env.FRONTEND_ORIGIN || true,
    credentials: true,
  })
);

const PORT = Number(process.env.PORT || 3000);
const JWT_SECRET = process.env.JWT_SECRET || 'change-me';
const TOKEN_EXPIRY_SECONDS = Number(process.env.TOKEN_EXPIRY_SECONDS || 3600);

const users = new Map();
const registrationOtps = new Map();
const passwordResetOtps = new Map();
const passwordResetTokens = new Map();

const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: Number(process.env.SMTP_PORT || 587),
  secure: String(process.env.SMTP_SECURE || 'false') === 'true',
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

function generateOtp() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

function generateJwt(user) {
  return jwt.sign(
    { userId: user.id, email: user.email },
    JWT_SECRET,
    { expiresIn: TOKEN_EXPIRY_SECONDS }
  );
}

function createExpiry(minutes) {
  return Date.now() + minutes * 60 * 1000;
}

function isExpired(expiresAt) {
  return Date.now() > expiresAt;
}

function sendMail({ to, subject, text, html }) {
  return transporter.sendMail({
    from: process.env.SMTP_FROM || process.env.SMTP_USER,
    to,
    subject,
    text,
    html,
  });
}

async function sendOtpEmail(to, otp, purpose) {
  const subject = purpose === 'registration'
    ? 'Resume Builder - Verify your email'
    : 'Resume Builder - Password reset OTP';

  const text = `Your OTP is ${otp}. It expires in 10 minutes.`;
  const html = `
    <div style="font-family:Arial,sans-serif;max-width:480px;margin:auto">
      <h2>${subject}</h2>
      <p>Your OTP is:</p>
      <p style="font-size:28px;font-weight:bold;letter-spacing:4px">${otp}</p>
      <p>This OTP expires in <b>10 minutes</b>.</p>
      <p>If you did not request this, ignore this email.</p>
    </div>
  `;

  await sendMail({ to, subject, text, html });
}

function authMiddleware(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;

  if (!token) {
    return res.status(401).json({ message: 'No token provided' });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    return next();
  } catch (_) {
    return res.status(401).json({ message: 'Invalid or expired token' });
  }
}

app.post('/auth/register', async (req, res) => {
  try {
    const name = String(req.body.name || '').trim();
    const email = normalizeEmail(req.body.email);
    const password = String(req.body.password || '');

    if (!name || !email || !password) {
      return res.status(400).json({ message: 'Name, email, password are required' });
    }

    if (users.has(email)) {
      return res.status(409).json({ message: 'Email already registered' });
    }

    if (password.length < 8) {
      return res.status(400).json({ message: 'Password must be at least 8 characters' });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const user = {
      id: crypto.randomUUID(),
      name,
      email,
      passwordHash,
      isVerified: false,
      createdAt: new Date().toISOString(),
    };

    users.set(email, user);

    const token = generateJwt(user);
    return res.status(201).json({
      token,
      expiresIn: TOKEN_EXPIRY_SECONDS,
      user: { id: user.id, name: user.name, email: user.email, isVerified: user.isVerified },
    });
  } catch (error) {
    return res.status(500).json({ message: 'Server error' });
  }
});

app.post('/auth/send-registration-otp', async (req, res) => {
  try {
    const email = normalizeEmail(req.body.email);
    const user = users.get(email);

    if (!email || !user) {
      return res.status(404).json({ message: 'User not found. Please sign up first.' });
    }

    const otp = generateOtp();
    registrationOtps.set(email, {
      otp,
      expiresAt: createExpiry(10),
    });

    await sendOtpEmail(email, otp, 'registration');
    return res.status(200).json({ message: 'OTP sent successfully' });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to send OTP email' });
  }
});

app.post('/auth/verify-registration-otp', (req, res) => {
  const email = normalizeEmail(req.body.email);
  const otp = String(req.body.otp || '').trim();

  const user = users.get(email);
  if (!user) {
    return res.status(404).json({ message: 'User not found' });
  }

  const saved = registrationOtps.get(email);
  if (!saved) {
    return res.status(400).json({ message: 'OTP expired. Please resend OTP.' });
  }

  if (isExpired(saved.expiresAt)) {
    registrationOtps.delete(email);
    return res.status(400).json({ message: 'OTP expired. Please resend OTP.' });
  }

  if (saved.otp !== otp) {
    return res.status(400).json({ message: 'Invalid OTP' });
  }

  user.isVerified = true;
  users.set(email, user);
  registrationOtps.delete(email);

  return res.status(200).json({ message: 'Email verified successfully' });
});

app.post('/auth/login', async (req, res) => {
  try {
    const email = normalizeEmail(req.body.email);
    const password = String(req.body.password || '');

    const user = users.get(email);
    if (!user) {
      return res.status(404).json({ message: 'User not found. Please sign up first.' });
    }

    if (!user.isVerified) {
      return res.status(403).json({ message: 'Please verify OTP sent to your email before login.' });
    }

    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) {
      return res.status(401).json({ message: 'Invalid email or password' });
    }

    const token = generateJwt(user);
    return res.status(200).json({
      token,
      expiresIn: TOKEN_EXPIRY_SECONDS,
      user: { id: user.id, name: user.name, email: user.email },
    });
  } catch (_) {
    return res.status(500).json({ message: 'Server error' });
  }
});

app.get('/auth/verify', authMiddleware, (req, res) => {
  const user = users.get(normalizeEmail(req.user.email));
  if (!user) {
    return res.status(401).json({ message: 'Invalid or expired token' });
  }

  return res.status(200).json({
    valid: true,
    userId: user.id,
    email: user.email,
    isVerified: user.isVerified,
  });
});

app.post('/auth/logout', authMiddleware, (_req, res) => {
  return res.status(200).json({ message: 'Logged out successfully' });
});

app.post('/auth/password-reset/send-otp', async (req, res) => {
  try {
    const email = normalizeEmail(req.body.email);
    const user = users.get(email);

    if (!email || !user) {
      return res.status(404).json({ message: 'No account found with this email.' });
    }

    const otp = generateOtp();
    passwordResetOtps.set(email, {
      otp,
      expiresAt: createExpiry(10),
    });

    await sendOtpEmail(email, otp, 'password-reset');
    return res.status(200).json({ message: 'OTP sent successfully' });
  } catch (_) {
    return res.status(500).json({ message: 'Failed to send OTP email' });
  }
});

app.post('/auth/password-reset/verify-otp', (req, res) => {
  const email = normalizeEmail(req.body.email);
  const otp = String(req.body.otp || '').trim();

  const user = users.get(email);
  if (!user) {
    return res.status(404).json({ message: 'User not found' });
  }

  const saved = passwordResetOtps.get(email);
  if (!saved) {
    return res.status(400).json({ message: 'OTP expired. Please resend OTP.' });
  }

  if (isExpired(saved.expiresAt)) {
    passwordResetOtps.delete(email);
    return res.status(400).json({ message: 'OTP expired. Please resend OTP.' });
  }

  if (saved.otp !== otp) {
    return res.status(400).json({ message: 'Invalid OTP' });
  }

  passwordResetOtps.delete(email);

  const resetToken = crypto.randomBytes(24).toString('hex');
  passwordResetTokens.set(resetToken, {
    email,
    expiresAt: createExpiry(10),
  });

  return res.status(200).json({
    message: 'OTP verified',
    resetToken,
  });
});

app.post('/auth/password-reset/change', async (req, res) => {
  try {
    const email = normalizeEmail(req.body.email);
    const resetToken = String(req.body.resetToken || '').trim();
    const newPassword = String(req.body.newPassword || '');

    const user = users.get(email);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const reset = passwordResetTokens.get(resetToken);
    if (!reset || reset.email !== email || isExpired(reset.expiresAt)) {
      return res.status(400).json({ message: 'Password reset session expired. Verify OTP again.' });
    }

    if (newPassword.length < 8) {
      return res.status(400).json({ message: 'Password must be at least 8 characters long' });
    }

    user.passwordHash = await bcrypt.hash(newPassword, 10);
    users.set(email, user);
    passwordResetTokens.delete(resetToken);

    await sendMail({
      to: email,
      subject: 'Resume Builder - Password changed',
      text: 'Your password has been changed successfully. If this was not you, contact support immediately.',
      html: '<p>Your password has been changed successfully.</p><p>If this was not you, contact support immediately.</p>',
    });

    return res.status(200).json({ message: 'Password changed successfully' });
  } catch (_) {
    return res.status(500).json({ message: 'Password change failed' });
  }
});

app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.listen(PORT, () => {
  console.log(`Auth backend running on http://localhost:${PORT}`);
});
