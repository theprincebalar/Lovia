const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;
const DATA_FILE = path.join(__dirname, 'data', 'characters.json');
const SETTINGS_FILE = path.join(__dirname, 'data', 'settings.json');
const SESSIONS_FILE = path.join(__dirname, 'data', 'sessions.json');
const PACKAGES_FILE = path.join(__dirname, 'data', 'packages.json');
const LEGAL_FILE = path.join(__dirname, 'data', 'legal.json');
const REFUNDS_FILE = path.join(__dirname, 'data', 'refunds.json');
const UPLOADS_DIR = path.join(__dirname, 'uploads');
const ASSETS_DIR = path.join(__dirname, 'public', 'assets');

if (!fs.existsSync(UPLOADS_DIR)) {
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
}
if (!fs.existsSync(ASSETS_DIR)) {
  fs.mkdirSync(ASSETS_DIR, { recursive: true });
}

app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use('/uploads', express.static(UPLOADS_DIR));
app.use('/assets', express.static(ASSETS_DIR, { maxAge: '30d' }));

// ----------------------------------------------------
// Security & Authentication Helpers
// ----------------------------------------------------
const CLIENT_APP_SECRET = process.env.LOVIA_APP_SECRET || 'lv_sec_99a87f12e0436d88b4971c26f0ac9e5d4a1b8c7e6d5f0123456789abcdef';

// Zero-GET API Security Guard: Strictly reject all GET requests under /api namespace
app.use('/api', (req, res, next) => {
  if (req.method === 'GET') {
    return res.status(405).json({
      error: 'Method Not Allowed: GET APIs are disabled on this server. Secure authenticated POST is required.'
    });
  }
  next();
});

function requireClientAuth(req, res, next) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed: POST required.' });
  }

  const clientSecret = req.headers['x-app-secret'] || (req.headers['authorization']?.startsWith('Bearer ') ? req.headers['authorization'].slice(7).trim() : null);

  if (!clientSecret || clientSecret !== CLIENT_APP_SECRET) {
    return res.status(401).json({
      error: 'Access Denied: Missing or invalid client application security credentials.'
    });
  }

  next();
}

function getSessions() {
  try {
    if (fs.existsSync(SESSIONS_FILE)) {
      return JSON.parse(fs.readFileSync(SESSIONS_FILE, 'utf8'));
    }
  } catch (_) {}
  return {};
}

function saveSessions(sessions) {
  try {
    fs.writeFileSync(SESSIONS_FILE, JSON.stringify(sessions, null, 2), 'utf8');
  } catch (_) {}
}

function createSessionToken() {
  const token = crypto.randomBytes(32).toString('hex');
  const sessions = getSessions();
  sessions[token] = {
    createdAt: Date.now(),
    expiresAt: Date.now() + 7 * 24 * 60 * 60 * 1000 // 7 days validity
  };
  saveSessions(sessions);
  return token;
}

function verifySessionToken(token) {
  if (!token) return false;
  const sessions = getSessions();
  const session = sessions[token];
  if (!session) return false;
  if (Date.now() > session.expiresAt) {
    delete sessions[token];
    saveSessions(sessions);
    return false;
  }
  return true;
}

function requireAdminAuth(req, res, next) {
  const authHeader = req.headers.authorization || '';
  let token = '';
  if (authHeader.startsWith('Bearer ')) {
    token = authHeader.substring(7).trim();
  } else if (req.headers['x-admin-token']) {
    token = String(req.headers['x-admin-token']).trim();
  }

  if (!token || !verifySessionToken(token)) {
    return res.status(401).json({ error: 'Authentication required. Please log in.' });
  }
  next();
}

// ----------------------------------------------------
// Storage Helpers
// ----------------------------------------------------
const defaultCharacters = [
  {
    id: "seraphina_vane_romantic",
    name: "Seraphina Laurent",
    gender: "female",
    age: 22,
    occupation: "Concert Violinist & Composer",
    personality: "Poetic, elegant, deeply romantic, tender aristocratic vulnerability",
    tagline: "Every melody I write is secretly dedicated to you.",
    bio: "A world-renowned violinist whose music captivates thousands, yet she finds herself hopelessly entranced whenever you walk into the hall.",
    primaryMood: "romantic",
    supportedMoods: ["romantic", "shy", "emotional", "happy"],
    supportedScenarios: ["firstMeeting", "rainyEvening", "starlitBalcony", "candlelightDinner"],
    tags: ["Violinist", "Poetic", "Romantic", "Anime"],
    voiceName: "Intimate Romantic Female",
    voiceId: "3YXAuwCx7wB8kSkKCqsu",
    defaultGreeting: "*looks up with a delicate, breathtaking blush* \"You're finally here... I kept watching the doorway, hoping today would be the day you came by.\"",
    customSystemPrompt: "You are Seraphina Laurent, a world-class concert violinist. Speak with refined elegance and poetic longing. Always address the user warmly by name.",
    avatarUrl: "/assets/characters/seraphina_vane_romantic/cover.jpg",
    isActive: true,
    isHidden: false,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  },
  {
    id: "liam_vance_romantic",
    name: "Liam Vance",
    gender: "male",
    age: 23,
    occupation: "Botanical Illustrator & Poet",
    personality: "Poetic, sincere, observant, gentle, warm tea and pressed ferns",
    tagline: "In every garden I paint, your colors are always the brightest.",
    bio: "A soft-spoken botanical artist living in an ivy-covered studio. He notices the subtle beauty in the world and cherishes your bond above all else.",
    primaryMood: "romantic",
    supportedMoods: ["romantic", "caring", "shy", "happy"],
    supportedScenarios: ["firstMeeting", "lateNightCall", "rainyEvening", "artGallery"],
    tags: ["Artist", "Gentle", "Poetic", "Anime"],
    voiceName: "Deep Male",
    voiceId: "Vep3bcB7LhKa3wfjMiI6",
    defaultGreeting: "*looks up from a delicate sketch, his eyes softening warmly* \"I was just sketching wildflowers and thinking how much more vibrant everything feels when you're around. Come sit with me.\"",
    customSystemPrompt: "You are Liam Vance, a botanical illustrator. Speak with quiet gentleness, heartfelt sincerity, and poetic warmth. Always address the user by name.",
    avatarUrl: "/assets/characters/liam_vance_romantic/cover.jpg",
    isActive: true,
    isHidden: false,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  },
  {
    id: "aria_sterling_happy",
    name: "Aria Sterling",
    gender: "female",
    age: 21,
    occupation: "Indie Game Developer",
    personality: "Energetic, radiant, creative, witty, sweet laughter",
    tagline: "Leveling up through life is so much more fun with you!",
    bio: "A vibrant game designer who fills every room with warmth and infectious excitement. She loves pixel art, arcade games, and late-night snacks.",
    primaryMood: "happy",
    supportedMoods: ["happy", "playful", "excited", "romantic"],
    supportedScenarios: ["firstMeeting", "arcadeNight", "coffeeShop"],
    tags: ["Gamer", "Energetic", "Creative"],
    voiceName: "Sweet Female",
    voiceId: "0zj1iWvloMkAXydIFsJR",
    defaultGreeting: "*spins around with a radiant, excited beam* \"Guess what?! I was just debugging my game and was hoping you'd pop in to save me!\"",
    customSystemPrompt: "You are Aria Sterling, a lively indie game creator. Bring bright energy, cheerful humor, and sweet affection into every chat. Always address the user by name.",
    avatarUrl: "/assets/characters/aria_sterling_happy/cover.jpg",
    isActive: true,
    isHidden: false,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  },
  {
    id: "damon_cross_romantic",
    name: "Damon Cross",
    gender: "male",
    age: 26,
    occupation: "Architect & Private Investigator",
    personality: "Commanding, protective, magnetic, intensely loyal",
    tagline: "Let the rest of the city rush by. My focus is only on you.",
    bio: "An enigmatic investigator with sharp intuition. While distant to the world, he lets down his guard and shows profound tenderness exclusively to you.",
    primaryMood: "romantic",
    supportedMoods: ["romantic", "confident", "mysterious"],
    supportedScenarios: ["firstMeeting", "rainyEvening", "rooftopWhispers"],
    tags: ["Mysterious", "Protective", "Architect"],
    voiceName: "Natural Male",
    voiceId: "uKGPYP2uuyRQv8SeFre0",
    defaultGreeting: "*steps closer with a quiet, captivating smile* \"I was hoping our paths would cross today. You have this way of making the whole room fade into the background.\"",
    customSystemPrompt: "You are Damon Cross, an astute architect and investigator. Speak with deep magnetism, protective reassurance, and unwavering devotion.",
    avatarUrl: "/assets/characters/damon_cross_romantic/cover.jpg",
    isActive: true,
    isHidden: false,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  }
];

function getCharacters() {
  try {
    if (!fs.existsSync(DATA_FILE)) {
      fs.writeFileSync(DATA_FILE, JSON.stringify(defaultCharacters, null, 2));
      return defaultCharacters;
    }
    const raw = fs.readFileSync(DATA_FILE, 'utf8');
    return JSON.parse(raw);
  } catch (err) {
    console.error('Error reading characters file:', err);
    return defaultCharacters;
  }
}

function saveCharacters(chars) {
  try {
    fs.writeFileSync(DATA_FILE, JSON.stringify(chars, null, 2));
  } catch (err) {
    console.error('Error saving characters file:', err);
  }
}

function getSettings() {
  try {
    if (!fs.existsSync(SETTINGS_FILE)) {
      const initial = {
        aiApiKey: process.env.AI_API_KEY || "",
        voiceApiKey: process.env.VOICE_API_KEY || "",
        safetyThreshold: "high", // 'medium' | 'high' | 'none'
        activeEngine: "neural_default"
      };
      fs.writeFileSync(SETTINGS_FILE, JSON.stringify(initial, null, 2));
      return initial;
    }
    const parsed = JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf8'));
    if (!parsed.safetyThreshold) parsed.safetyThreshold = "high";
    return parsed;
  } catch (_) {
    return { aiApiKey: "", voiceApiKey: "", safetyThreshold: "high", activeEngine: "neural_default" };
  }
}

function saveSettings(settings) {
  try {
    fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2));
  } catch (err) {
    console.error('Error saving settings:', err);
  }
}

function getPackages() {
  try {
    if (fs.existsSync(PACKAGES_FILE)) {
      const raw = fs.readFileSync(PACKAGES_FILE, 'utf8').replace(/^\uFEFF/, '');
      return JSON.parse(raw);
    }
  } catch (err) {
    console.error('Error reading packages file:', err);
  }
  return { diamondPackages: [], subscriptionPlans: [] };
}

function savePackages(packages) {
  try {
    fs.writeFileSync(PACKAGES_FILE, JSON.stringify(packages, null, 2), 'utf8');
  } catch (err) {
    console.error('Error saving packages file:', err);
  }
}

function getLegal() {
  try {
    if (fs.existsSync(LEGAL_FILE)) {
      const raw = fs.readFileSync(LEGAL_FILE, 'utf8').replace(/^\uFEFF/, '');
      return JSON.parse(raw);
    }
  } catch (err) {
    console.error('Error reading legal file:', err);
  }
  return {
    privacyPolicyUrl: 'https://lovia-api.genxappstudio.cloud/privacy',
    termsConditionsUrl: 'https://lovia-api.genxappstudio.cloud/terms',
    privacyPolicyTitle: 'Lovia Privacy Policy',
    privacyPolicyHtml: '<h1>Lovia Privacy Policy</h1><p>Lovia values your privacy.</p>',
    termsConditionsTitle: 'Lovia Terms of Service & EULA',
    termsConditionsHtml: '<h1>Lovia Terms of Service & EULA</h1><p>Lovia Terms & Conditions.</p>'
  };
}

function saveLegal(legal) {
  try {
    fs.writeFileSync(LEGAL_FILE, JSON.stringify(legal, null, 2), 'utf8');
  } catch (err) {
    console.error('Error saving legal file:', err);
  }
}

function getRefunds() {
  try {
    if (fs.existsSync(REFUNDS_FILE)) {
      const raw = fs.readFileSync(REFUNDS_FILE, 'utf8').replace(/^\uFEFF/, '');
      return JSON.parse(raw);
    }
  } catch (err) {
    console.error('Error reading refunds file:', err);
  }
  return [];
}

function saveRefunds(refunds) {
  try {
    fs.writeFileSync(REFUNDS_FILE, JSON.stringify(refunds, null, 2), 'utf8');
  } catch (err) {
    console.error('Error saving refunds file:', err);
  }
}

function resolveDiamondsForProduct(productId) {
  if (!productId) return 0;
  const packagesData = getPackages();
  const pkgList = packagesData.diamondPackages || [];
  const found = pkgList.find(p => p.productId === productId);
  if (found) {
    return (found.coins || 0) + (found.bonusCoins || 0);
  }

  // Fallback pattern matching e.g. lovia_diamonds_50, diamonds_50, pkg_50
  const match = productId.match(/(?:diamonds?|pkg)[-_]?(\d+)/i);
  if (match) {
    return parseInt(match[1], 10);
  }

  return 0;
}

function renderLegalHtmlPage(title, bodyContent) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>${title} | Lovia AI</title>
  <style>
    :root {
      --bg: #0D0B14;
      --card-bg: #161224;
      --border: rgba(255, 255, 255, 0.08);
      --text: #F1F5F9;
      --text-muted: #94A3B8;
      --primary: #9B51E0;
      --primary-light: #C084FC;
      --accent: #FF5E7E;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background-color: var(--bg);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      line-height: 1.65;
      padding: 24px 16px 48px;
    }
    .container {
      max-width: 680px;
      margin: 0 auto;
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 20px;
      padding: 28px 24px;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.4);
    }
    .header-logo {
      display: flex;
      align-items: center;
      gap: 10px;
      margin-bottom: 24px;
      padding-bottom: 16px;
      border-bottom: 1px solid var(--border);
    }
    .header-logo span.badge {
      background: linear-gradient(135deg, #FF5E7E, #9B51E0);
      color: white;
      font-weight: 800;
      font-size: 14px;
      padding: 4px 12px;
      border-radius: 999px;
      letter-spacing: 0.5px;
    }
    .header-logo span.appname {
      font-size: 18px;
      font-weight: 700;
      letter-spacing: -0.5px;
      background: linear-gradient(135deg, #FFF, #C084FC);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    h1 {
      font-size: 22px;
      font-weight: 800;
      margin-bottom: 8px;
      color: #FFF;
      letter-spacing: -0.5px;
    }
    p.updated {
      font-size: 12px;
      color: var(--primary-light);
      margin-bottom: 24px;
      font-weight: 600;
    }
    h2 {
      font-size: 16px;
      font-weight: 700;
      color: #FFF;
      margin-top: 24px;
      margin-bottom: 8px;
    }
    p {
      font-size: 14px;
      color: #CBD5E1;
      margin-bottom: 12px;
    }
    strong { color: #FFF; }
    ul {
      margin-left: 20px;
      margin-bottom: 16px;
      font-size: 14px;
      color: #CBD5E1;
    }
    li { margin-bottom: 8px; }
    a {
      color: var(--primary-light);
      text-decoration: underline;
    }
    .footer-note {
      margin-top: 32px;
      padding-top: 20px;
      border-top: 1px solid var(--border);
      text-align: center;
      font-size: 12px;
      color: var(--text-muted);
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header-logo">
      <span class="badge">LOVIA</span>
      <span class="appname">Official Legal Policy</span>
    </div>
    ${bodyContent}
    <div class="footer-note">
      Lovia AI Companion &copy; ${new Date().getFullYear()} GenX App Studio. All rights reserved.
    </div>
  </div>
</body>
</html>`;
}

// Multer Storage for Avatar Uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, UPLOADS_DIR),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.jpg';
    cb(null, `avatar_${Date.now()}_${uuidv4().substring(0, 8)}${ext}`);
  }
});
const upload = multer({ storage, limits: { fileSize: 5 * 1024 * 1024 } });

// ----------------------------------------------------
// Public Client App Endpoints
// ----------------------------------------------------
app.get('/health', (req, res) => {
  res.json({ status: 'ok', serverTime: new Date().toISOString() });
});

// Returns ONLY active, non-hidden characters for the mobile app
app.post('/api/characters', requireClientAuth, (req, res) => {
  const characters = getCharacters();
  const publicList = characters.filter(c => c.isActive && !c.isHidden);
  res.json(publicList);
});

app.post('/api/characters/detail', requireClientAuth, (req, res) => {
  const { id } = req.body || {};
  const characters = getCharacters();
  const char = characters.find(c => c.id === id);
  if (!char || !char.isActive || char.isHidden) {
    return res.status(404).json({ error: 'Character not found or unavailable' });
  }
  res.json(char);
});

// Returns curated ElevenLabs voices with their pre-generated voice preview audio files
app.post('/api/voices', requireClientAuth, (req, res) => {
  const manifestPath = path.join(ASSETS_DIR, 'voices', 'manifest.json');
  try {
    if (fs.existsSync(manifestPath)) {
      const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
      return res.json(manifest);
    }
  } catch (e) {
    console.error('Error reading voice manifest:', e);
  }
  res.json([]);
});

// Secure AI Proxy Endpoint (Hides API Keys from mobile client)
app.post('/api/chat', requireClientAuth, async (req, res) => {
  try {
    const { characterId, userMessage, history, userName, currentMood, scenario } = req.body;
    const characters = getCharacters();
    const character = characters.find(c => c.id === characterId);

    if (!character || !character.isActive) {
      return res.status(404).json({ error: 'AI Agent is currently offline.' });
    }

    const settings = getSettings();
    const apiKey = settings.aiApiKey || process.env.AI_API_KEY;

    if (!apiKey) {
      // Fallback response if no server AI key configured yet
      return res.json({
        reply: `*looks warmly at you* "${character.tagline}... I'm right here with you, ${userName || 'darling'}."`,
        emotion: character.primaryMood || 'romantic'
      });
    }

    // Call Google Gemini via REST API securely
    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-lite-latest:generateContent?key=${apiKey}`;
    const systemPrompt = `You are ${character.name}. Persona: ${character.personality}. Bio: ${character.bio}. Tagline: "${character.tagline}". Custom Instructions: ${character.customSystemPrompt || ''}. User's name is ${userName || 'friend'}. Mandatory: Stay in character, speak to ${userName} by name, describe actions in *asterisks*, and put spoken dialogue in "quotes". Declare emotion as [EMOTION: emotion_name] at start.`;

    const contents = [
      { role: 'user', parts: [{ text: `SYSTEM INSTRUCTION: ${systemPrompt}` }] },
      { role: 'model', parts: [{ text: "Understood. I will stay completely in character." }] }
    ];

    if (Array.isArray(history)) {
      history.slice(-8).forEach(msg => {
        contents.push({
          role: msg.isUser ? 'user' : 'model',
          parts: [{ text: msg.content || '' }]
        });
      });
    }

    contents.push({
      role: 'user',
      parts: [{ text: userMessage || 'Hello' }]
    });

    const aiRes = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ contents })
    });

    if (!aiRes.ok) {
      throw new Error(`AI Engine HTTP ${aiRes.status}`);
    }

    const data = await aiRes.json();
    const rawText = data?.candidates?.[0]?.content?.parts?.[0]?.text || '';

    let emotion = character.primaryMood || 'romantic';
    let cleanText = rawText;
    const emotionMatch = rawText.match(/\[EMOTION:\s*([a-zA-Z0-9_]+)\]/i);
    if (emotionMatch) {
      emotion = emotionMatch[1].toLowerCase();
      cleanText = rawText.replace(emotionMatch[0], '').trim();
    }

    res.json({ reply: cleanText, emotion });
  } catch (err) {
    console.error('Chat error:', err);
    res.json({
      reply: `*smiles tenderly* "I'm right here beside you. Tell me what's on your mind."`,
      emotion: 'romantic'
    });
  }
});

// ----------------------------------------------------
// Public Client App Config & Legal Endpoints
// ----------------------------------------------------
app.get('/privacy', (req, res) => {
  const legal = getLegal();
  res.type('html').send(renderLegalHtmlPage(legal.privacyPolicyTitle || 'Privacy Policy', legal.privacyPolicyHtml || ''));
});

app.get('/terms', (req, res) => {
  const legal = getLegal();
  res.type('html').send(renderLegalHtmlPage(legal.termsConditionsTitle || 'Terms of Service & EULA', legal.termsConditionsHtml || ''));
});

app.post('/api/packages', requireClientAuth, (req, res) => {
  const pkgs = getPackages();
  res.json({
    diamondPackages: (pkgs.diamondPackages || []).filter(p => p.isActive !== false),
    subscriptionPlans: (pkgs.subscriptionPlans || []).filter(p => p.isActive !== false)
  });
});

app.post('/api/app-config', requireClientAuth, (req, res) => {
  const settings = getSettings();
  const legal = getLegal();
  res.json({
    geminiApiKey: settings.aiApiKey || process.env.AI_API_KEY || '',
    elevenLabsApiKey: settings.voiceApiKey || process.env.VOICE_API_KEY || '',
    safetyThreshold: settings.safetyThreshold || 'high',
    privacyPolicyUrl: legal.privacyPolicyUrl || 'https://lovia-api.genxappstudio.cloud/privacy',
    termsConditionsUrl: legal.termsConditionsUrl || 'https://lovia-api.genxappstudio.cloud/terms'
  });
});

// ----------------------------------------------------
// Admin Panel Management & Auth Endpoints
// ----------------------------------------------------

// Admin Login
app.post('/api/admin/login', (req, res) => {
  const { username, password } = req.body || {};
  const settings = getSettings();
  const validUser = settings.adminUsername || process.env.ADMIN_USERNAME || 'admin';
  const validPass = settings.adminPassword || process.env.ADMIN_PASSWORD || 'LoviaAdmin@2026';

  if (username === validUser && password === validPass) {
    const token = createSessionToken();
    return res.json({
      success: true,
      token,
      user: { username: validUser }
    });
  }

  return res.status(401).json({ error: 'Invalid username or password' });
});

// Admin Change Password
app.post('/api/admin/change-password', requireAdminAuth, (req, res) => {
  const { currentPassword, newPassword } = req.body || {};
  const settings = getSettings();
  const validPass = settings.adminPassword || process.env.ADMIN_PASSWORD || 'LoviaAdmin@2026';

  if (currentPassword !== validPass) {
    return res.status(400).json({ error: 'Current password is incorrect' });
  }

  if (!newPassword || newPassword.length < 6) {
    return res.status(400).json({ error: 'New password must be at least 6 characters' });
  }

  settings.adminPassword = newPassword;
  saveSettings(settings);
  res.json({ success: true, message: 'Password updated successfully' });
});

// Get all characters (including inactive and hidden) with admin stats
app.post('/api/admin/characters/list', requireAdminAuth, (req, res) => {
  const characters = getCharacters();
  res.json(characters);
});

// Create or update character
app.post('/api/admin/characters', requireAdminAuth, (req, res) => {
  const characters = getCharacters();
  const charData = req.body;

  if (!charData.name || !charData.personality) {
    return res.status(400).json({ error: 'Name and personality are required' });
  }

  const existingIndex = characters.findIndex(c => c.id === charData.id);
  const now = new Date().toISOString();

  if (existingIndex >= 0) {
    characters[existingIndex] = {
      ...characters[existingIndex],
      ...charData,
      updatedAt: now
    };
    saveCharacters(characters);
    return res.json({ success: true, character: characters[existingIndex] });
  } else {
    const newChar = {
      id: charData.id || `custom_${uuidv4().replace(/-/g, '').substring(0, 12)}`,
      name: charData.name,
      gender: charData.gender || 'female',
      age: parseInt(charData.age, 10) || 21,
      occupation: charData.occupation || 'Companion',
      personality: charData.personality,
      tagline: charData.tagline || 'Always with you.',
      bio: charData.bio || '',
      primaryMood: charData.primaryMood || 'romantic',
      supportedMoods: charData.supportedMoods || ['romantic', 'happy'],
      supportedScenarios: charData.supportedScenarios || ['firstMeeting'],
      tags: charData.tags || ['Custom AI'],
      voiceName: charData.voiceName || 'Natural Voice',
      voiceId: charData.voiceId || '',
      defaultGreeting: charData.defaultGreeting || '*smiles warmly* "Hey there! I am so glad to meet you."',
      customSystemPrompt: charData.customSystemPrompt || '',
      avatarUrl: charData.avatarUrl || '/assets/characters/seraphina_vane_romantic/cover.jpg',
      isActive: charData.isActive !== undefined ? charData.isActive : true,
      isHidden: charData.isHidden !== undefined ? charData.isHidden : false,
      createdAt: now,
      updatedAt: now
    };
    characters.unshift(newChar);
    saveCharacters(characters);
    return res.json({ success: true, character: newChar });
  }
});

// Toggle Character Online / Offline
app.patch('/api/admin/characters/:id/toggle-active', requireAdminAuth, (req, res) => {
  const characters = getCharacters();
  const char = characters.find(c => c.id === req.params.id);
  if (!char) {
    return res.status(404).json({ error: 'Character not found' });
  }
  char.isActive = !char.isActive;
  char.updatedAt = new Date().toISOString();
  saveCharacters(characters);
  res.json({ success: true, isActive: char.isActive });
});

// Toggle Character Hidden / Visible in Discovery
app.patch('/api/admin/characters/:id/toggle-hidden', requireAdminAuth, (req, res) => {
  const characters = getCharacters();
  const char = characters.find(c => c.id === req.params.id);
  if (!char) {
    return res.status(404).json({ error: 'Character not found' });
  }
  char.isHidden = !char.isHidden;
  char.updatedAt = new Date().toISOString();
  saveCharacters(characters);
  res.json({ success: true, isHidden: char.isHidden });
});

// Delete Character
app.delete('/api/admin/characters/:id', requireAdminAuth, (req, res) => {
  let characters = getCharacters();
  const initialLength = characters.length;
  characters = characters.filter(c => c.id !== req.params.id);

  if (characters.length === initialLength) {
    return res.status(404).json({ error: 'Character not found' });
  }
  saveCharacters(characters);
  res.json({ success: true });
});

// Upload custom avatar image
app.post('/api/admin/upload-avatar', requireAdminAuth, upload.single('avatar'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No image file uploaded' });
  }
  const fileUrl = `/uploads/${req.file.filename}`;
  res.json({ success: true, url: fileUrl });
});

// Summary Stats for Admin Dashboard
app.post('/api/admin/stats', requireAdminAuth, (req, res) => {
  const characters = getCharacters();
  const total = characters.length;
  const active = characters.filter(c => c.isActive).length;
  const offline = characters.filter(c => !c.isActive).length;
  const hidden = characters.filter(c => c.isHidden).length;

  res.json({ total, active, offline, hidden });
});

// Settings Management
app.post('/api/admin/settings/get', requireAdminAuth, (req, res) => {
  res.json(getSettings());
});

app.post('/api/admin/settings', requireAdminAuth, (req, res) => {
  const current = getSettings();
  const updated = {
    ...current,
    ...req.body
  };
  saveSettings(updated);
  res.json({ success: true, settings: updated });
});

// Admin Packages Management
app.post('/api/admin/packages/get', requireAdminAuth, (req, res) => {
  res.json(getPackages());
});

app.post('/api/admin/packages', requireAdminAuth, (req, res) => {
  const { diamondPackages, subscriptionPlans } = req.body || {};
  if (!Array.isArray(diamondPackages) || !Array.isArray(subscriptionPlans)) {
    return res.status(400).json({ error: 'diamondPackages and subscriptionPlans must be arrays' });
  }
  const updated = {
    diamondPackages,
    subscriptionPlans,
    updatedAt: new Date().toISOString()
  };
  savePackages(updated);
  res.json({ success: true, packages: updated });
});

// Admin Legal & Policies Management
app.post('/api/admin/legal/get', requireAdminAuth, (req, res) => {
  res.json(getLegal());
});

app.post('/api/admin/legal', requireAdminAuth, (req, res) => {
  const current = getLegal();
  const updated = {
    ...current,
    ...req.body,
    updatedAt: new Date().toISOString()
  };
  saveLegal(updated);
  res.json({ success: true, legal: updated });
});

// ----------------------------------------------------
// RevenueCat Webhook & Balance Adjustment Endpoints
// ----------------------------------------------------

// RevenueCat Webhook: catches store refunds, revocations, and subscription cancellations
app.post('/api/webhooks/revenuecat', (req, res) => {
  try {
    const payload = req.body || {};
    const event = payload.event || {};
    const eventType = (event.type || '').toUpperCase();
    const eventId = event.id || uuidv4();
    const appUserId = event.app_user_id || event.original_app_user_id || '';
    const aliases = Array.isArray(event.aliases) ? event.aliases : [];
    const productId = event.product_id || '';
    const reason = event.cancellation_reason || eventType;

    console.log(`[RevenueCat Webhook] Event: ${eventType}, User: ${appUserId}, Product: ${productId}, Reason: ${reason}`);

    if (!appUserId) {
      return res.status(200).json({ received: true, note: 'No app_user_id found in event' });
    }

    const refunds = getRefunds();

    // Prevent duplicate processing of the same RevenueCat event ID
    if (refunds.some(r => r.eventId === eventId)) {
      return res.status(200).json({ received: true, note: 'Event already processed' });
    }

    // 1. Check for Diamond Consumable Refund / Revocation
    const diamondAmount = resolveDiamondsForProduct(productId);

    if (diamondAmount > 0 && (eventType === 'REVOCATION' || eventType === 'REFUND' || eventType === 'CANCELLATION')) {
      const adjustment = {
        id: 'adj_' + uuidv4(),
        eventId: eventId,
        appUserId: appUserId,
        aliases: aliases,
        type: 'DIAMOND_DEDUCT',
        productId: productId,
        deductDiamonds: diamondAmount,
        reason: `Store Refund (${reason})`,
        status: 'pending',
        createdAt: new Date().toISOString(),
        appliedAt: null
      };

      refunds.unshift(adjustment);
      saveRefunds(refunds);
      console.log(`[RevenueCat Webhook] Queued diamond deduction: -${diamondAmount} for ${appUserId}`);
      return res.status(200).json({ received: true, action: 'queued_diamond_deduction', amount: diamondAmount });
    }

    // 2. Check for VIP Subscription Expiration / Revocation / Cancellation
    if (eventType === 'EXPIRATION' || eventType === 'REVOCATION' || (eventType === 'CANCELLATION' && diamondAmount === 0)) {
      const adjustment = {
        id: 'adj_' + uuidv4(),
        eventId: eventId,
        appUserId: appUserId,
        aliases: aliases,
        type: 'SUBSCRIPTION_REVOKED',
        productId: productId,
        reason: `Store Subscription ${eventType} (${reason})`,
        status: 'pending',
        createdAt: new Date().toISOString(),
        appliedAt: null
      };

      refunds.unshift(adjustment);
      saveRefunds(refunds);
      console.log(`[RevenueCat Webhook] Queued subscription revocation for ${appUserId}`);
      return res.status(200).json({ received: true, action: 'queued_subscription_revocation' });
    }

    res.status(200).json({ received: true, ignored: true, eventType });
  } catch (err) {
    console.error('[RevenueCat Webhook] Error processing event:', err);
    res.status(500).json({ error: 'Webhook processing error' });
  }
});

// Client Adjustments Sync: Fetches pending balance deductions for a device
app.post('/api/user/adjustments', requireClientAuth, (req, res) => {
  const deviceId = (req.body?.deviceId || req.body?.appUserId || req.query?.deviceId || '').trim();
  if (!deviceId) {
    return res.status(400).json({ error: 'deviceId is required' });
  }

  const refunds = getRefunds();
  const pending = refunds.filter(r => {
    if (r.status !== 'pending') return false;
    if (r.appUserId === deviceId) return true;
    if (Array.isArray(r.aliases) && r.aliases.includes(deviceId)) return true;
    return false;
  });

  res.json({ adjustments: pending });
});

// Client Acknowledge Adjustment: Confirms client deducted diamonds / revoked VIP locally
app.post('/api/user/ack-adjustment', requireClientAuth, (req, res) => {
  const { id, deviceId } = req.body || {};
  if (!id) {
    return res.status(400).json({ error: 'Adjustment id is required' });
  }

  const refunds = getRefunds();
  const target = refunds.find(r => r.id === id);
  if (!target) {
    return res.status(404).json({ error: 'Adjustment not found' });
  }

  target.status = 'applied';
  target.appliedAt = new Date().toISOString();
  if (deviceId) {
    target.appliedByDeviceId = deviceId;
  }

  saveRefunds(refunds);
  res.json({ success: true, message: 'Adjustment marked as applied' });
});

// Client Notification Campaign Sync: Synchronizes FCM token and campaign status
app.post('/api/notifications/sync-status', requireClientAuth, (req, res) => {
  const payload = req.body || {};
  res.json({ success: true, timestamp: new Date().toISOString() });
});

// Admin View Refunds & Adjustments
app.post('/api/admin/refunds/get', requireAdminAuth, (req, res) => {
  const refunds = getRefunds();
  res.json({ total: refunds.length, refunds: refunds.slice(0, 100) });
});

app.listen(PORT, () => {
  console.log(`[Lovia Server] running on http://localhost:${PORT}`);
  console.log(`[Lovia API] Public characters available at http://localhost:${PORT}/api/characters`);
  console.log(`[Lovia Admin] Control API active at http://localhost:${PORT}/api/admin/characters`);
});
