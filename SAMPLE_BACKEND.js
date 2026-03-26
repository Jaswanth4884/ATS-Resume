// Sample Node.js/Express Backend Implementation
// This is a reference implementation showing how to build the backend endpoints

const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const cors = require('cors');
require('dotenv').config();

const app = express();
app.use(express.json());
app.use(cors());

// Secret key for JWT signing (store in .env)
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-this';
const TOKEN_EXPIRY = 3600; // 1 hour in seconds

// In-memory user store (use real database in production)
const users = new Map();

// Hash password (use bcrypt in production)
async function hashPassword(password) {
  return bcrypt.hash(password, 10);
}

// Compare password
async function comparePassword(password, hash) {
  return bcrypt.compare(password, hash);
}

// Generate JWT token
function generateToken(userId, email) {
  return jwt.sign(
    { userId, email },
    JWT_SECRET,
    { expiresIn: TOKEN_EXPIRY }
  );
}

// Middleware to verify token
function verifyToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ message: 'No token provided' });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.userId = decoded.userId;
    req.email = decoded.email;
    next();
  } catch (error) {
    return res.status(401).json({ message: 'Invalid or expired token' });
  }
}

// ========== ENDPOINTS ==========

// Login endpoint
app.post('/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    // Validate input
    if (!email || !password) {
      return res.status(400).json({ message: 'Email and password required' });
    }

    // Find user
    const user = users.get(email);
    if (!user) {
      return res.status(404).json({ message: 'User not found. Please sign up first.' });
    }

    // Verify password
    const passwordValid = await comparePassword(password, user.passwordHash);
    if (!passwordValid) {
      return res.status(401).json({ message: 'Invalid email or password' });
    }

    // Generate token
    const token = generateToken(user.id, email);

    res.json({
      token,
      expiresIn: TOKEN_EXPIRY,
      user: {
        id: user.id,
        email: user.email,
        name: user.name
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Register endpoint
app.post('/auth/register', async (req, res) => {
  try {
    const { email, password, name } = req.body;

    // Validate input
    if (!email || !password || !name) {
      return res.status(400).json({ message: 'Email, password, and name required' });
    }

    // Check if user exists
    if (users.has(email)) {
      return res.status(409).json({ message: 'Email already registered' });
    }

    // Hash password
    const passwordHash = await hashPassword(password);

    // Create user
    const userId = `user_${Date.now()}`;
    users.set(email, {
      id: userId,
      email,
      name,
      passwordHash,
      createdAt: new Date()
    });

    // Generate token
    const token = generateToken(userId, email);

    res.status(201).json({
      token,
      expiresIn: TOKEN_EXPIRY,
      user: { id: userId, email, name }
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Verify token endpoint
app.get('/auth/verify', verifyToken, (req, res) => {
  const user = users.get(req.email);
  res.json({
    valid: true,
    userId: req.userId,
    email: req.email,
    user: {
      name: user?.name,
      email: user?.email
    }
  });
});

// Refresh token endpoint
app.post('/auth/refresh', verifyToken, (req, res) => {
  try {
    const token = generateToken(req.userId, req.email);
    res.json({
      token,
      expiresIn: TOKEN_EXPIRY
    });
  } catch (error) {
    res.status(500).json({ message: 'Server error' });
  }
});

// Logout endpoint
app.post('/auth/logout', verifyToken, (req, res) => {
  // In a real app, you might blacklist the token here
  res.json({ message: 'Logged out successfully' });
});

// Password reset endpoint
app.post('/auth/password-reset', (req, res) => {
  const { email } = req.body;

  if (!email) {
    return res.status(400).json({ message: 'Email required' });
  }

  if (!users.has(email)) {
    // Don't reveal if email exists (security best practice)
    return res.json({ message: 'If email is registered, reset link sent' });
  }

  // TODO: Send reset email with token
  res.json({ message: 'Reset link sent to email' });
});

// Example protected endpoint
app.get('/user/profile', verifyToken, (req, res) => {
  const user = users.get(req.email);
  if (!user) {
    return res.status(404).json({ message: 'User not found' });
  }

  res.json({
    user: {
      id: user.id,
      email: user.email,
      name: user.name,
      createdAt: user.createdAt
    }
  });
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});

// ========== USAGE ==========
/*
  To run this sample backend:
  
  1. Install dependencies:
     npm install express jsonwebtoken bcryptjs cors dotenv
  
  2. Create .env file:
     JWT_SECRET=your-super-secret-key-change-this-in-production
     PORT=3000
  
  3. Start server:
     node server.js
  
  4. Test endpoints with curl or Postman:
  
     Register:
     curl -X POST http://localhost:3000/auth/register \
       -H "Content-Type: application/json" \
       -d '{"email":"user@example.com","password":"Test123","name":"John Doe"}'
  
     Login:
     curl -X POST http://localhost:3000/auth/login \
       -H "Content-Type: application/json" \
       -d '{"email":"user@example.com","password":"Test123"}'
  
     Verify (replace TOKEN with actual token):
     curl http://localhost:3000/auth/verify \
       -H "Authorization: Bearer TOKEN"
  
     Logout:
     curl -X POST http://localhost:3000/auth/logout \
       -H "Authorization: Bearer TOKEN"
*/

// ========== PRODUCTION CHECKLIST ==========
/*
  For production deployment:
  
  ✓ Use real database (MongoDB, PostgreSQL, etc.)
  ✓ Move JWT_SECRET to secure environment variable
  ✓ Enable HTTPS
  ✓ Implement token blacklisting for logout
  ✓ Add request rate limiting
  ✓ Add input validation & sanitization
  ✓ Implement password reset with email verification
  ✓ Add logging and monitoring
  ✓ Use environment-based configuration
  ✓ Implement proper error handling
  ✓ Add authentication logging for security events
  ✓ Use strong password hashing (bcrypt/argon2)
  ✓ Implement CORS properly (don't allow all origins)
  ✓ Add database migrations
  ✓ Set up automated backups
  ✓ Use API keys for sensitive endpoints
  ✓ Implement 2FA if needed
*/
