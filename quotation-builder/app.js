// ===== Firebase Configuration =====
const firebaseConfig = {
  apiKey: "AIzaSyDLgRLbWVTTAWHz_NUAsaNamb-cVPRSvGI",
  authDomain: "ats-resume-98571.firebaseapp.com",
  projectId: "ats-resume-98571",
  storageBucket: "ats-resume-98571.firebasestorage.app",
  messagingSenderId: "1065762162388",
  appId: "1:1065762162388:web:6c43f162ba47e682685d41",
  measurementId: "G-062BCXHY5X"
};

firebase.initializeApp(firebaseConfig);
const auth = firebase.auth();
const db = firebase.firestore();

// ===== App State =====
let currentUser = null;
let quotations = [];
let clients = [];
let companySettings = {};
let editingQuoteId = null;
let editingClientId = null;
let itemRowCounter = 0;

// ===== Auth Functions =====
let pendingVerificationUser = null;
let resendCooldown = 0;
let resendInterval = null;

function toggleAuthMode(e) {
  e.preventDefault();
  const loginForm = document.getElementById('auth-login-form');
  const registerForm = document.getElementById('auth-register-form');
  const verifyScreen = document.getElementById('auth-verify-screen');
  const isLogin = loginForm.style.display !== 'none';
  loginForm.style.display = isLogin ? 'none' : 'block';
  registerForm.style.display = isLogin ? 'block' : 'none';
  verifyScreen.style.display = 'none';
  hideAuthError();
}

function showAuthScreen(screen) {
  document.getElementById('auth-login-form').style.display = screen === 'login' ? 'block' : 'none';
  document.getElementById('auth-register-form').style.display = screen === 'register' ? 'block' : 'none';
  document.getElementById('auth-verify-screen').style.display = screen === 'verify' ? 'block' : 'none';
  hideAuthError();
}

function showAuthError(msg) {
  const el = document.getElementById('auth-error');
  el.textContent = msg;
  el.style.display = 'block';
}
function hideAuthError() {
  document.getElementById('auth-error').style.display = 'none';
}

async function handleLogin() {
  hideAuthError();
  const email = document.getElementById('auth-email').value.trim();
  const pass = document.getElementById('auth-password').value;
  if (!email || !pass) return showAuthError('Please fill in all fields');
  
  const btn = document.getElementById('auth-login-btn');
  btn.innerHTML = '<span class="loading-spinner"></span> Signing in...';
  btn.disabled = true;
  
  try {
    const result = await auth.signInWithEmailAndPassword(email, pass);
    
    // Check if email is verified
    if (!result.user.emailVerified) {
      // Sign them out — they need to verify first
      pendingVerificationUser = result.user;
      document.getElementById('verify-email-display').textContent = result.user.email;
      showAuthScreen('verify');
      await auth.signOut();
      return;
    }
  } catch (err) {
    showAuthError(getAuthErrorMessage(err.code));
  } finally {
    btn.innerHTML = '<span class="material-icons-round">login</span> Sign In';
    btn.disabled = false;
  }
}

async function handleRegister() {
  hideAuthError();
  const name = document.getElementById('reg-name').value.trim();
  const email = document.getElementById('reg-email').value.trim();
  const pass = document.getElementById('reg-password').value;
  if (!name || !email || !pass) return showAuthError('Please fill in all fields');
  if (pass.length < 6) return showAuthError('Password must be at least 6 characters');
  
  const btn = document.getElementById('auth-register-btn');
  btn.innerHTML = '<span class="loading-spinner"></span> Creating account...';
  btn.disabled = true;
  
  try {
    const result = await auth.createUserWithEmailAndPassword(email, pass);
    
    // Set display name
    await result.user.updateProfile({ displayName: name });
    
    // Send verification email
    await result.user.sendEmailVerification();
    
    // Store reference for resend
    pendingVerificationUser = result.user;
    
    // Show verification screen
    document.getElementById('verify-email-display').textContent = email;
    showAuthScreen('verify');
    startResendCooldown();
    
    // Sign out — they should verify first
    await auth.signOut();
    
  } catch (err) {
    showAuthError(getAuthErrorMessage(err.code));
  } finally {
    btn.innerHTML = '<span class="material-icons-round">person_add</span> Create Account';
    btn.disabled = false;
  }
}

async function resendVerificationEmail() {
  hideAuthError();
  if (resendCooldown > 0) return;
  
  const btn = document.getElementById('resend-verify-btn');
  btn.innerHTML = '<span class="loading-spinner"></span> Sending...';
  btn.disabled = true;
  
  try {
    // We need to sign in again briefly to resend
    const email = document.getElementById('verify-email-display').textContent.trim();
    const pass = document.getElementById('reg-password').value || document.getElementById('auth-password').value;
    
    if (!pass) {
      showAuthError('Please go back and sign in with your password to resend the verification.');
      btn.innerHTML = '<span class="material-icons-round">refresh</span> Resend Verification Email';
      btn.disabled = false;
      return;
    }
    
    const result = await auth.signInWithEmailAndPassword(email, pass);
    await result.user.sendEmailVerification();
    await auth.signOut();
    
    startResendCooldown();
    showAuthError('');
    const errEl = document.getElementById('auth-error');
    errEl.textContent = '✓ Verification email sent! Check your inbox.';
    errEl.style.display = 'block';
    errEl.style.background = 'var(--green-bg)';
    errEl.style.borderColor = 'rgba(16, 185, 129, 0.3)';
    errEl.style.color = '#6ee7b7';
    
  } catch (err) {
    showAuthError(getAuthErrorMessage(err.code));
  } finally {
    btn.innerHTML = '<span class="material-icons-round">refresh</span> Resend Verification Email';
    btn.disabled = resendCooldown > 0;
  }
}

function startResendCooldown() {
  resendCooldown = 60;
  const btn = document.getElementById('resend-verify-btn');
  const timerEl = document.getElementById('resend-timer');
  btn.disabled = true;
  timerEl.style.display = 'block';
  
  if (resendInterval) clearInterval(resendInterval);
  resendInterval = setInterval(() => {
    resendCooldown--;
    if (resendCooldown <= 0) {
      clearInterval(resendInterval);
      resendInterval = null;
      btn.disabled = false;
      timerEl.style.display = 'none';
    } else {
      timerEl.textContent = `You can resend in ${resendCooldown}s`;
    }
  }, 1000);
  timerEl.textContent = `You can resend in ${resendCooldown}s`;
}

function backToLogin() {
  pendingVerificationUser = null;
  showAuthScreen('login');
  // Reset error styling
  const errEl = document.getElementById('auth-error');
  errEl.style.background = '';
  errEl.style.borderColor = '';
  errEl.style.color = '';
}

async function handleGoogleLogin() {
  hideAuthError();
  try {
    const provider = new firebase.auth.GoogleAuthProvider();
    await auth.signInWithPopup(provider);
    // Google accounts are auto-verified, no check needed
  } catch (err) {
    if (err.code !== 'auth/popup-closed-by-user') {
      showAuthError(getAuthErrorMessage(err.code));
    }
  }
}

async function handleLogout() {
  try { await auth.signOut(); } catch (err) { console.error(err); }
}

function getAuthErrorMessage(code) {
  const messages = {
    'auth/user-not-found': 'No account found with this email',
    'auth/wrong-password': 'Incorrect password',
    'auth/email-already-in-use': 'An account already exists with this email',
    'auth/weak-password': 'Password should be at least 6 characters',
    'auth/invalid-email': 'Invalid email address',
    'auth/too-many-requests': 'Too many attempts. Please try again later',
    'auth/network-request-failed': 'Network error. Check your connection',
    'auth/invalid-credential': 'Invalid email or password',
    'auth/operation-not-allowed': 'Email/Password sign-in is not enabled. Please enable it in the Firebase Console → Authentication → Sign-in method.',
    'auth/admin-restricted-operation': 'Sign-up is restricted. Please enable Email/Password in Firebase Console → Authentication → Sign-in method.',
    'auth/configuration-not-found': 'Firebase Auth is not configured. Please enable Authentication in the Firebase Console.',
  };
  console.error('Auth error code:', code);
  return messages[code] || `Authentication error (${code || 'unknown'}). Please try again.`;
}

// Auth listener
auth.onAuthStateChanged(user => {
  currentUser = user;
  if (user) {
    // Only allow verified users (Google users are auto-verified)
    if (!user.emailVerified && user.providerData[0]?.providerId === 'password') {
      // Unverified email/password user — show verify screen
      pendingVerificationUser = user;
      document.getElementById('verify-email-display').textContent = user.email;
      showAuthScreen('verify');
      document.getElementById('auth-screen').style.display = 'flex';
      document.getElementById('app').style.display = 'none';
      auth.signOut();
      return;
    }
    
    document.getElementById('auth-screen').style.display = 'none';
    document.getElementById('app').style.display = 'flex';
    updateUserUI(user);
    loadAllData();
  } else {
    document.getElementById('auth-screen').style.display = 'flex';
    document.getElementById('app').style.display = 'none';
    quotations = [];
    clients = [];
    companySettings = {};
  }
});

function updateUserUI(user) {
  const name = user.displayName || user.email.split('@')[0];
  document.getElementById('user-display-name').textContent = name;
  document.getElementById('user-email-display').textContent = user.email;
  document.getElementById('user-avatar').textContent = name.charAt(0).toUpperCase();
}

// ===== Data Loading =====
async function loadAllData() {
  if (!currentUser) return;
  const uid = currentUser.uid;
  
  // Load quotations
  try {
    const snap = await db.collection('quotations')
      .where('userId', '==', uid)
      .orderBy('createdAt', 'desc')
      .get();
    quotations = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
  } catch (err) {
    console.error('Error loading quotations:', err);
    quotations = [];
  }
  
  // Load clients
  try {
    const snap = await db.collection('clients')
      .where('userId', '==', uid)
      .orderBy('name')
      .get();
    clients = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
  } catch (err) {
    console.error('Error loading clients:', err);
    clients = [];
  }
  
  // Load company settings
  try {
    const doc = await db.collection('company').doc(uid).get();
    companySettings = doc.exists ? doc.data() : {};
  } catch (err) {
    console.error('Error loading settings:', err);
    companySettings = {};
  }
  
  applySettingsToForm();
  updateDashboard();
  renderQuotationsList('all-quotes-list');
  renderClientsList();
}

// ===== Navigation =====
function switchView(viewName) {
  document.querySelectorAll('.view').forEach(v => v.classList.remove('active-view'));
  document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
  
  document.getElementById(`view-${viewName}`).classList.add('active-view');
  document.querySelector(`[data-view="${viewName}"]`)?.classList.add('active');
  
  if (viewName === 'create' && !editingQuoteId) {
    resetCreateForm();
  }
  
  if (viewName === 'quotations') {
    renderQuotationsList('all-quotes-list');
  }
  
  if (viewName === 'clients') {
    renderClientsList();
  }
  
  // Close mobile sidebar
  document.getElementById('sidebar').classList.remove('open');
  document.getElementById('sidebar-overlay').classList.remove('open');
}

function toggleSidebar() {
  document.getElementById('sidebar').classList.toggle('open');
  document.getElementById('sidebar-overlay').classList.toggle('open');
}

// ===== Dashboard =====
function updateDashboard() {
  const total = quotations.length;
  const pending = quotations.filter(q => q.status === 'sent' || q.status === 'draft').length;
  const accepted = quotations.filter(q => q.status === 'accepted').length;
  const revenue = quotations
    .filter(q => q.status === 'accepted')
    .reduce((sum, q) => sum + (q.grandTotal || 0), 0);
  
  document.getElementById('stat-total').textContent = total;
  document.getElementById('stat-pending').textContent = pending;
  document.getElementById('stat-accepted').textContent = accepted;
  document.getElementById('stat-revenue').textContent = formatCurrency(revenue);
  
  renderRecentQuotes();
}

function renderRecentQuotes() {
  const container = document.getElementById('recent-quotes-list');
  const recent = quotations.slice(0, 5);
  
  if (recent.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <span class="material-icons-round">receipt_long</span>
        <p>No quotations yet. Create your first one!</p>
      </div>`;
    return;
  }
  
  container.innerHTML = recent.map(q => renderQuoteCard(q)).join('');
}

// ===== Quotation CRUD =====
function renderQuoteCard(q) {
  const date = q.date || 'N/A';
  const clientName = q.clientName || 'Unknown Client';
  const subject = q.subject || 'Untitled';
  return `
    <div class="quote-card" onclick="editQuotation('${q.id}')">
      <div class="quote-card-info">
        <div class="quote-card-title">${escapeHtml(subject)}</div>
        <div class="quote-card-meta">
          <span>${escapeHtml(clientName)}</span>
          <span>${q.quoteNumber || ''}</span>
          <span>${date}</span>
          <span class="status-badge status-${q.status || 'draft'}">${q.status || 'draft'}</span>
        </div>
      </div>
      <div class="quote-card-amount">${formatCurrency(q.grandTotal || 0)}</div>
      <div class="quote-card-actions">
        <button class="btn-icon" onclick="event.stopPropagation(); duplicateQuotation('${q.id}')" title="Duplicate">
          <span class="material-icons-round">content_copy</span>
        </button>
        <button class="btn-icon" onclick="event.stopPropagation(); deleteQuotation('${q.id}')" title="Delete" style="color:var(--red)">
          <span class="material-icons-round">delete_outline</span>
        </button>
      </div>
    </div>`;
}

function renderQuotationsList(containerId) {
  const container = document.getElementById(containerId);
  const searchTerm = document.getElementById('search-quotes')?.value?.toLowerCase() || '';
  const filtered = quotations.filter(q => {
    if (!searchTerm) return true;
    return (q.subject || '').toLowerCase().includes(searchTerm) ||
           (q.clientName || '').toLowerCase().includes(searchTerm) ||
           (q.quoteNumber || '').toLowerCase().includes(searchTerm);
  });
  
  if (filtered.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <span class="material-icons-round">receipt_long</span>
        <p>${searchTerm ? 'No matching quotations found' : 'No quotations yet. Create your first one!'}</p>
      </div>`;
    return;
  }
  
  container.innerHTML = filtered.map(q => renderQuoteCard(q)).join('');
}

function filterQuotations() {
  renderQuotationsList('all-quotes-list');
}

function resetCreateForm() {
  editingQuoteId = null;
  document.getElementById('create-view-title').textContent = 'Create New Quotation';
  document.getElementById('client-name').value = '';
  document.getElementById('client-email').value = '';
  document.getElementById('client-phone').value = '';
  document.getElementById('client-gst').value = '';
  document.getElementById('client-address').value = '';
  document.getElementById('quote-subject').value = '';
  document.getElementById('quote-status').value = 'draft';
  document.getElementById('quote-notes').value = companySettings.defaultNotes || '';
  document.getElementById('quote-terms').value = companySettings.defaultTerms || '';
  document.getElementById('discount-percent').value = '0';
  document.getElementById('tax-percent').value = companySettings.defaultTax || '18';
  
  // Set dates
  const today = new Date();
  document.getElementById('quote-date').value = formatDateInput(today);
  const validDate = new Date(today);
  validDate.setDate(validDate.getDate() + 30);
  document.getElementById('quote-valid-until').value = formatDateInput(validDate);
  
  // Generate quote number
  const prefix = companySettings.quotePrefix || 'QTN-';
  const num = String(quotations.length + 1).padStart(4, '0');
  document.getElementById('quote-number').value = `${prefix}${num}`;
  
  // Reset items
  const tbody = document.getElementById('items-tbody');
  tbody.innerHTML = '';
  itemRowCounter = 0;
  addItemRow();
  recalcTotals();
}

function addItemRow(item = null) {
  itemRowCounter++;
  const tbody = document.getElementById('items-tbody');
  const row = document.createElement('tr');
  row.id = `item-row-${itemRowCounter}`;
  const rowNum = itemRowCounter;
  
  row.innerHTML = `
    <td class="col-num" style="text-align:center;color:var(--text-muted)">${rowNum}</td>
    <td><input type="text" placeholder="Item description" value="${escapeHtml(item?.description || '')}" onchange="recalcTotals()" /></td>
    <td><input type="number" min="0" step="1" value="${item?.qty || 1}" onchange="recalcTotals()" style="text-align:right" /></td>
    <td><input type="text" value="${escapeHtml(item?.unit || 'Nos')}" style="text-align:center" /></td>
    <td><input type="number" min="0" step="0.01" value="${item?.rate || 0}" onchange="recalcTotals()" style="text-align:right" /></td>
    <td class="item-amount">₹0.00</td>
    <td>
      <button class="btn-icon" onclick="removeItemRow('item-row-${itemRowCounter}')" style="color:var(--red)">
        <span class="material-icons-round" style="font-size:18px">close</span>
      </button>
    </td>`;
  
  tbody.appendChild(row);
  recalcTotals();
}

function removeItemRow(rowId) {
  const row = document.getElementById(rowId);
  if (row) {
    row.remove();
    renumberItems();
    recalcTotals();
  }
}

function renumberItems() {
  const rows = document.querySelectorAll('#items-tbody tr');
  rows.forEach((row, i) => {
    row.querySelector('.col-num').textContent = i + 1;
  });
}

function getItemsFromTable() {
  const rows = document.querySelectorAll('#items-tbody tr');
  const items = [];
  rows.forEach(row => {
    const inputs = row.querySelectorAll('input');
    const description = inputs[0]?.value?.trim() || '';
    const qty = parseFloat(inputs[1]?.value) || 0;
    const unit = inputs[2]?.value?.trim() || 'Nos';
    const rate = parseFloat(inputs[3]?.value) || 0;
    if (description) {
      items.push({ description, qty, unit, rate, amount: qty * rate });
    }
  });
  return items;
}

function recalcTotals() {
  const rows = document.querySelectorAll('#items-tbody tr');
  let subtotal = 0;
  const cs = companySettings.currencySymbol || '₹';
  
  rows.forEach(row => {
    const inputs = row.querySelectorAll('input');
    const qty = parseFloat(inputs[1]?.value) || 0;
    const rate = parseFloat(inputs[3]?.value) || 0;
    const amount = qty * rate;
    subtotal += amount;
    row.querySelector('.item-amount').textContent = `${cs}${amount.toFixed(2)}`;
  });
  
  const discountPct = parseFloat(document.getElementById('discount-percent').value) || 0;
  const taxPct = parseFloat(document.getElementById('tax-percent').value) || 0;
  const discount = subtotal * (discountPct / 100);
  const afterDiscount = subtotal - discount;
  const tax = afterDiscount * (taxPct / 100);
  const grandTotal = afterDiscount + tax;
  
  document.getElementById('subtotal').textContent = `${cs}${subtotal.toFixed(2)}`;
  document.getElementById('discount-amount').textContent = `-${cs}${discount.toFixed(2)}`;
  document.getElementById('tax-amount').textContent = `${cs}${tax.toFixed(2)}`;
  document.getElementById('grand-total').textContent = `${cs}${grandTotal.toFixed(2)}`;
}

async function saveQuotation() {
  if (!currentUser) return;
  
  const clientName = document.getElementById('client-name').value.trim();
  if (!clientName) return showToast('Please enter client name', 'error');
  
  const items = getItemsFromTable();
  if (items.length === 0) return showToast('Please add at least one item', 'error');
  
  const cs = companySettings.currencySymbol || '₹';
  const subtotal = items.reduce((sum, i) => sum + i.amount, 0);
  const discountPct = parseFloat(document.getElementById('discount-percent').value) || 0;
  const taxPct = parseFloat(document.getElementById('tax-percent').value) || 0;
  const discount = subtotal * (discountPct / 100);
  const afterDiscount = subtotal - discount;
  const tax = afterDiscount * (taxPct / 100);
  const grandTotal = afterDiscount + tax;
  
  const data = {
    userId: currentUser.uid,
    clientName,
    clientEmail: document.getElementById('client-email').value.trim(),
    clientPhone: document.getElementById('client-phone').value.trim(),
    clientGst: document.getElementById('client-gst').value.trim(),
    clientAddress: document.getElementById('client-address').value.trim(),
    quoteNumber: document.getElementById('quote-number').value.trim(),
    date: document.getElementById('quote-date').value,
    validUntil: document.getElementById('quote-valid-until').value,
    status: document.getElementById('quote-status').value,
    subject: document.getElementById('quote-subject').value.trim(),
    items,
    subtotal, discountPct, discount, taxPct, tax, grandTotal,
    currencySymbol: cs,
    notes: document.getElementById('quote-notes').value.trim(),
    terms: document.getElementById('quote-terms').value.trim(),
    updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
  };
  
  try {
    if (editingQuoteId) {
      await db.collection('quotations').doc(editingQuoteId).update(data);
      showToast('Quotation updated successfully!');
    } else {
      data.createdAt = firebase.firestore.FieldValue.serverTimestamp();
      await db.collection('quotations').add(data);
      showToast('Quotation created successfully!');
    }
    
    await loadAllData();
    switchView('quotations');
  } catch (err) {
    console.error('Error saving quotation:', err);
    showToast('Error saving quotation. Please try again.', 'error');
  }
}

function editQuotation(id) {
  const q = quotations.find(q => q.id === id);
  if (!q) return;
  
  editingQuoteId = id;
  document.getElementById('create-view-title').textContent = 'Edit Quotation';
  document.getElementById('client-name').value = q.clientName || '';
  document.getElementById('client-email').value = q.clientEmail || '';
  document.getElementById('client-phone').value = q.clientPhone || '';
  document.getElementById('client-gst').value = q.clientGst || '';
  document.getElementById('client-address').value = q.clientAddress || '';
  document.getElementById('quote-number').value = q.quoteNumber || '';
  document.getElementById('quote-date').value = q.date || '';
  document.getElementById('quote-valid-until').value = q.validUntil || '';
  document.getElementById('quote-status').value = q.status || 'draft';
  document.getElementById('quote-subject').value = q.subject || '';
  document.getElementById('quote-notes').value = q.notes || '';
  document.getElementById('quote-terms').value = q.terms || '';
  document.getElementById('discount-percent').value = q.discountPct || 0;
  document.getElementById('tax-percent').value = q.taxPct || 18;
  
  // Populate items
  const tbody = document.getElementById('items-tbody');
  tbody.innerHTML = '';
  itemRowCounter = 0;
  if (q.items && q.items.length > 0) {
    q.items.forEach(item => addItemRow(item));
  } else {
    addItemRow();
  }
  recalcTotals();
  
  switchView('create');
}

async function duplicateQuotation(id) {
  const q = quotations.find(q => q.id === id);
  if (!q || !currentUser) return;
  
  const prefix = companySettings.quotePrefix || 'QTN-';
  const num = String(quotations.length + 1).padStart(4, '0');
  
  const copy = { ...q };
  delete copy.id;
  copy.quoteNumber = `${prefix}${num}`;
  copy.status = 'draft';
  copy.date = formatDateInput(new Date());
  copy.subject = `${copy.subject || 'Untitled'} (Copy)`;
  copy.createdAt = firebase.firestore.FieldValue.serverTimestamp();
  copy.updatedAt = firebase.firestore.FieldValue.serverTimestamp();
  
  try {
    await db.collection('quotations').add(copy);
    showToast('Quotation duplicated!');
    await loadAllData();
  } catch (err) {
    showToast('Error duplicating quotation', 'error');
  }
}

async function deleteQuotation(id) {
  if (!confirm('Are you sure you want to delete this quotation?')) return;
  
  try {
    await db.collection('quotations').doc(id).delete();
    showToast('Quotation deleted');
    await loadAllData();
  } catch (err) {
    showToast('Error deleting quotation', 'error');
  }
}

// ===== Clients CRUD =====
function renderClientsList() {
  const container = document.getElementById('clients-list');
  
  if (clients.length === 0) {
    container.innerHTML = `
      <div class="empty-state" style="grid-column: 1 / -1">
        <span class="material-icons-round">people</span>
        <p>No clients yet. Add your first client!</p>
      </div>`;
    return;
  }
  
  container.innerHTML = clients.map(c => `
    <div class="client-card">
      <div class="client-card-header">
        <div class="client-card-avatar">${(c.name || '?').charAt(0).toUpperCase()}</div>
        <div class="client-card-name">${escapeHtml(c.name)}</div>
      </div>
      <div class="client-card-details">
        ${c.email ? `<span><span class="material-icons-round">email</span>${escapeHtml(c.email)}</span>` : ''}
        ${c.phone ? `<span><span class="material-icons-round">phone</span>${escapeHtml(c.phone)}</span>` : ''}
        ${c.address ? `<span><span class="material-icons-round">location_on</span>${escapeHtml(c.address)}</span>` : ''}
      </div>
      <div class="client-card-footer">
        <button class="btn btn-outline btn-sm" onclick="editClient('${c.id}')">
          <span class="material-icons-round" style="font-size:16px">edit</span> Edit
        </button>
        <button class="btn btn-outline btn-sm" onclick="useClientInQuote('${c.id}')">
          <span class="material-icons-round" style="font-size:16px">receipt_long</span> Quote
        </button>
        <button class="btn-icon" onclick="deleteClient('${c.id}')" title="Delete" style="color:var(--red)">
          <span class="material-icons-round" style="font-size:18px">delete_outline</span>
        </button>
      </div>
    </div>`).join('');
}

function showAddClientModal() {
  editingClientId = null;
  document.getElementById('client-modal-title').textContent = 'Add Client';
  document.getElementById('modal-client-name').value = '';
  document.getElementById('modal-client-email').value = '';
  document.getElementById('modal-client-phone').value = '';
  document.getElementById('modal-client-gst').value = '';
  document.getElementById('modal-client-address').value = '';
  document.getElementById('client-modal').style.display = 'flex';
}

function editClient(id) {
  const c = clients.find(c => c.id === id);
  if (!c) return;
  editingClientId = id;
  document.getElementById('client-modal-title').textContent = 'Edit Client';
  document.getElementById('modal-client-name').value = c.name || '';
  document.getElementById('modal-client-email').value = c.email || '';
  document.getElementById('modal-client-phone').value = c.phone || '';
  document.getElementById('modal-client-gst').value = c.gst || '';
  document.getElementById('modal-client-address').value = c.address || '';
  document.getElementById('client-modal').style.display = 'flex';
}

async function saveClient() {
  if (!currentUser) return;
  const name = document.getElementById('modal-client-name').value.trim();
  if (!name) return showToast('Please enter client name', 'error');
  
  const data = {
    userId: currentUser.uid,
    name,
    email: document.getElementById('modal-client-email').value.trim(),
    phone: document.getElementById('modal-client-phone').value.trim(),
    gst: document.getElementById('modal-client-gst').value.trim(),
    address: document.getElementById('modal-client-address').value.trim(),
    updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
  };
  
  try {
    if (editingClientId) {
      await db.collection('clients').doc(editingClientId).update(data);
      showToast('Client updated!');
    } else {
      data.createdAt = firebase.firestore.FieldValue.serverTimestamp();
      await db.collection('clients').add(data);
      showToast('Client added!');
    }
    closeModal('client-modal');
    await loadAllData();
  } catch (err) {
    showToast('Error saving client', 'error');
  }
}

async function deleteClient(id) {
  if (!confirm('Delete this client?')) return;
  try {
    await db.collection('clients').doc(id).delete();
    showToast('Client deleted');
    await loadAllData();
  } catch (err) {
    showToast('Error deleting client', 'error');
  }
}

function useClientInQuote(id) {
  const c = clients.find(c => c.id === id);
  if (!c) return;
  resetCreateForm();
  document.getElementById('client-name').value = c.name || '';
  document.getElementById('client-email').value = c.email || '';
  document.getElementById('client-phone').value = c.phone || '';
  document.getElementById('client-gst').value = c.gst || '';
  document.getElementById('client-address').value = c.address || '';
  switchView('create');
}

// ===== Company Settings =====
function applySettingsToForm() {
  document.getElementById('company-name').value = companySettings.companyName || '';
  document.getElementById('company-email').value = companySettings.companyEmail || '';
  document.getElementById('company-phone').value = companySettings.companyPhone || '';
  document.getElementById('company-gst').value = companySettings.companyGst || '';
  document.getElementById('company-address').value = companySettings.companyAddress || '';
  document.getElementById('currency-symbol').value = companySettings.currencySymbol || '₹';
  document.getElementById('default-tax').value = companySettings.defaultTax || '18';
  document.getElementById('quote-prefix').value = companySettings.quotePrefix || 'QTN-';
  document.getElementById('default-terms').value = companySettings.defaultTerms || '';
  document.getElementById('default-notes').value = companySettings.defaultNotes || '';
}

async function saveSettings() {
  if (!currentUser) return;
  
  companySettings = {
    companyName: document.getElementById('company-name').value.trim(),
    companyEmail: document.getElementById('company-email').value.trim(),
    companyPhone: document.getElementById('company-phone').value.trim(),
    companyGst: document.getElementById('company-gst').value.trim(),
    companyAddress: document.getElementById('company-address').value.trim(),
    currencySymbol: document.getElementById('currency-symbol').value.trim() || '₹',
    defaultTax: document.getElementById('default-tax').value,
    quotePrefix: document.getElementById('quote-prefix').value.trim() || 'QTN-',
    defaultTerms: document.getElementById('default-terms').value.trim(),
    defaultNotes: document.getElementById('default-notes').value.trim(),
    updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
  };
  
  try {
    await db.collection('company').doc(currentUser.uid).set(companySettings, { merge: true });
    showToast('Settings saved!');
  } catch (err) {
    showToast('Error saving settings', 'error');
  }
}

// ===== Preview & Print =====
function previewQuotation() {
  const cs = companySettings.currencySymbol || '₹';
  const items = getItemsFromTable();
  const subtotal = items.reduce((sum, i) => sum + i.amount, 0);
  const discountPct = parseFloat(document.getElementById('discount-percent').value) || 0;
  const taxPct = parseFloat(document.getElementById('tax-percent').value) || 0;
  const discount = subtotal * (discountPct / 100);
  const afterDiscount = subtotal - discount;
  const tax = afterDiscount * (taxPct / 100);
  const grandTotal = afterDiscount + tax;
  
  const companyName = companySettings.companyName || 'Your Company';
  const companyDetails = [
    companySettings.companyEmail,
    companySettings.companyPhone,
    companySettings.companyAddress,
    companySettings.companyGst ? `GST: ${companySettings.companyGst}` : '',
  ].filter(Boolean).join('<br>');
  
  const preview = document.getElementById('quotation-preview');
  preview.innerHTML = `
    <div class="qp-header">
      <div>
        <div class="qp-company-name">${escapeHtml(companyName)}</div>
        <div class="qp-company-details">${companyDetails || 'Configure company details in Settings'}</div>
      </div>
      <div>
        <div class="qp-title">QUOTATION</div>
        <div class="qp-quote-number">${escapeHtml(document.getElementById('quote-number').value)}</div>
      </div>
    </div>
    
    <div class="qp-parties">
      <div class="qp-party">
        <div class="qp-party-label">Bill To</div>
        <div class="qp-party-name">${escapeHtml(document.getElementById('client-name').value || 'Client Name')}</div>
        <div class="qp-party-details">
          ${document.getElementById('client-email').value ? escapeHtml(document.getElementById('client-email').value) + '<br>' : ''}
          ${document.getElementById('client-phone').value ? escapeHtml(document.getElementById('client-phone').value) + '<br>' : ''}
          ${document.getElementById('client-address').value ? escapeHtml(document.getElementById('client-address').value) + '<br>' : ''}
          ${document.getElementById('client-gst').value ? 'GST: ' + escapeHtml(document.getElementById('client-gst').value) : ''}
        </div>
      </div>
    </div>
    
    <div class="qp-meta-row">
      <div class="qp-meta-item">
        <div class="qp-meta-label">Date</div>
        <div class="qp-meta-value">${document.getElementById('quote-date').value || 'N/A'}</div>
      </div>
      <div class="qp-meta-item">
        <div class="qp-meta-label">Valid Until</div>
        <div class="qp-meta-value">${document.getElementById('quote-valid-until').value || 'N/A'}</div>
      </div>
      <div class="qp-meta-item">
        <div class="qp-meta-label">Status</div>
        <div class="qp-meta-value" style="text-transform:capitalize">${document.getElementById('quote-status').value}</div>
      </div>
    </div>
    
    ${document.getElementById('quote-subject').value ? `<div style="margin-bottom:20px"><strong>Subject:</strong> ${escapeHtml(document.getElementById('quote-subject').value)}</div>` : ''}
    
    <table class="qp-items-table">
      <thead>
        <tr>
          <th>#</th>
          <th>Description</th>
          <th style="text-align:right">Qty</th>
          <th style="text-align:center">Unit</th>
          <th style="text-align:right">Rate</th>
          <th style="text-align:right">Amount</th>
        </tr>
      </thead>
      <tbody>
        ${items.map((item, i) => `
          <tr>
            <td>${i + 1}</td>
            <td>${escapeHtml(item.description)}</td>
            <td style="text-align:right">${item.qty}</td>
            <td style="text-align:center">${escapeHtml(item.unit)}</td>
            <td style="text-align:right">${cs}${item.rate.toFixed(2)}</td>
            <td style="text-align:right">${cs}${item.amount.toFixed(2)}</td>
          </tr>
        `).join('')}
      </tbody>
    </table>
    
    <div class="qp-totals">
      <div class="qp-totals-row">
        <span>Subtotal</span>
        <span>${cs}${subtotal.toFixed(2)}</span>
      </div>
      ${discountPct > 0 ? `
        <div class="qp-totals-row">
          <span>Discount (${discountPct}%)</span>
          <span>-${cs}${discount.toFixed(2)}</span>
        </div>` : ''}
      ${taxPct > 0 ? `
        <div class="qp-totals-row">
          <span>Tax / GST (${taxPct}%)</span>
          <span>${cs}${tax.toFixed(2)}</span>
        </div>` : ''}
      <div class="qp-totals-row qp-totals-grand">
        <span>Grand Total</span>
        <span>${cs}${grandTotal.toFixed(2)}</span>
      </div>
    </div>
    
    ${document.getElementById('quote-notes').value ? `
      <div class="qp-section">
        <div class="qp-section-title">Notes</div>
        <div class="qp-section-text">${escapeHtml(document.getElementById('quote-notes').value)}</div>
      </div>` : ''}
    
    ${document.getElementById('quote-terms').value ? `
      <div class="qp-section">
        <div class="qp-section-title">Terms & Conditions</div>
        <div class="qp-section-text">${escapeHtml(document.getElementById('quote-terms').value)}</div>
      </div>` : ''}
    
    <div class="qp-footer">
      Generated by Resume Builder &bull; ${new Date().toLocaleDateString()}
    </div>`;
  
  document.getElementById('preview-modal').style.display = 'flex';
}

function printQuotation() {
  window.print();
}

function downloadPDF() {
  // Use browser print-to-PDF as fallback
  showToast('Use Print → Save as PDF to download');
  window.print();
}

// ===== Modals =====
function closeModal(id) {
  document.getElementById(id).style.display = 'none';
}

// Close modal on backdrop click
document.addEventListener('click', e => {
  if (e.target.classList.contains('modal')) {
    e.target.style.display = 'none';
  }
});

// ===== Toast =====
function showToast(message, type = 'success') {
  const toast = document.getElementById('toast');
  const icon = document.querySelector('.toast-icon');
  document.getElementById('toast-message').textContent = message;
  
  if (type === 'error') {
    icon.textContent = 'error';
    icon.style.color = 'var(--red)';
  } else {
    icon.textContent = 'check_circle';
    icon.style.color = 'var(--green)';
  }
  
  toast.style.display = 'flex';
  clearTimeout(toast._timer);
  toast._timer = setTimeout(() => { toast.style.display = 'none'; }, 3000);
}

// ===== Utilities =====
function formatCurrency(amount) {
  const cs = companySettings.currencySymbol || '₹';
  return `${cs}${amount.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function formatDateInput(date) {
  return date.toISOString().split('T')[0];
}

function escapeHtml(str) {
  if (!str) return '';
  const map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
  return str.replace(/[&<>"']/g, c => map[c]);
}

// Keyboard shortcuts
document.addEventListener('keydown', e => {
  if (e.key === 'Escape') {
    document.querySelectorAll('.modal').forEach(m => m.style.display = 'none');
  }
});

// Enter key on auth forms
document.addEventListener('keypress', e => {
  if (e.key === 'Enter') {
    if (e.target.id === 'auth-email' || e.target.id === 'auth-password') {
      handleLogin();
    } else if (e.target.id === 'reg-name' || e.target.id === 'reg-email' || e.target.id === 'reg-password') {
      handleRegister();
    }
  }
});
