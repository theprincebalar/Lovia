import React, { useState, useEffect } from 'react';
import PackagesManager from './PackagesManager';
import LegalManager from './LegalManager';

const API_BASE = '/api';

const CURATED_VOICES = [
  { voiceId: 'uKGPYP2uuyRQv8SeFre0', name: 'Natural Male', gender: 'male' },
  { voiceId: '3svOJAOhuPHXwQC2H5eq', name: 'Friendly Male', gender: 'male' },
  { voiceId: 'Vep3bcB7LhKa3wfjMiI6', name: 'Deep Male', gender: 'male' },
  { voiceId: '7WggD3IoWTIPT19PNyrW', name: 'Effortless Male', gender: 'male' },
  { voiceId: 'Myap7vX7L9ipoJVdyOVZ', name: 'Intimate Male', gender: 'male' },
  { voiceId: 'EozfaQ3ZX0esAp1cW5nG', name: 'Deep Resonant Male', gender: 'male' },
  { voiceId: 'oaLGpwm7fYWDEFmlRuQk', name: 'Intimate Soft Male', gender: 'male' },
  { voiceId: 'hYZHGYzFnp1GKImhQtGi', name: 'Funny Male', gender: 'male' },
  { voiceId: 'LyZq9ggDlPpK7b17wpjG', name: 'Deep Velvet Male', gender: 'male' },
  { voiceId: 'inGcvmoPgbvKUk9uCvHu', name: 'Sad / Tender Male', gender: 'male' },
  { voiceId: '4NejU5DwQjevnR6mh3mb', name: 'Expressive Female', gender: 'female' },
  { voiceId: 'uYXf8XasLslADfZ2MB4u', name: 'Gossip Female', gender: 'female' },
  { voiceId: '0zj1iWvloMkAXydIFsJR', name: 'Sweet Female', gender: 'female' },
  { voiceId: '3YXAuwCx7wB8kSkKCqsu', name: 'Intimate Romantic Female', gender: 'female' },
  { voiceId: 'xYa75LlayhWHCRl1yJSH', name: 'Intimate Sensual Female', gender: 'female' },
  { voiceId: 'h61MhzGbN77HK91UuRr8', name: 'Intimate Alluring Female', gender: 'female' },
  { voiceId: '2NzqTfQARqdn4tcBKTSh', name: 'Talkative Female', gender: 'female' },
  { voiceId: 'CyHwTRKhXEYuSd7CbMwI', name: 'Funny Female', gender: 'female' },
  { voiceId: 'm3yAHyFEFKtbCIM5n7GF', name: 'Sad / Gentle Female', gender: 'female' },
];

export default function App() {
  const [token, setToken] = useState(() => localStorage.getItem('lovia_admin_token') || '');
  const [loginUsername, setLoginUsername] = useState('admin');
  const [loginPassword, setLoginPassword] = useState('');
  const [loginError, setLoginError] = useState('');
  const [isLoggingIn, setIsLoggingIn] = useState(false);
  const [pwdCurrent, setPwdCurrent] = useState('');
  const [pwdNew, setPwdNew] = useState('');
  const [isChangingPwd, setIsChangingPwd] = useState(false);
  const [playingVoiceId, setPlayingVoiceId] = useState(null);
  const audioRef = React.useRef(new Audio());

  const handlePlayVoice = (vId) => {
    if (!vId) return;
    if (playingVoiceId === vId) {
      audioRef.current.pause();
      setPlayingVoiceId(null);
      return;
    }
    audioRef.current.pause();
    audioRef.current.src = `https://lovia-api.genxappstudio.cloud/assets/voices/${vId}.mp3`;
    audioRef.current.play().then(() => {
      setPlayingVoiceId(vId);
    }).catch(e => console.error('Audio play error:', e));
    audioRef.current.onended = () => setPlayingVoiceId(null);
  };

  const [characters, setCharacters] = useState([]);
  const [stats, setStats] = useState({ total: 0, active: 0, offline: 0, hidden: 0 });
  const [search, setSearch] = useState('');
  const [genderFilter, setGenderFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [serverOnline, setServerOnline] = useState(false);
  const [loading, setLoading] = useState(true);
  const [currentNavTab, setCurrentNavTab] = useState('characters'); // 'characters' | 'packages' | 'legal'

  // Modals
  const [editingChar, setEditingChar] = useState(null);
  const [isCreateOpen, setIsCreateOpen] = useState(false);
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const [settings, setSettings] = useState({
    aiApiKey: '',
    voiceApiKey: '',
    safetyThreshold: 'high',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=com.lovia.ai.friend.app.lovia',
    appStoreUrl: 'https://apps.apple.com/app/id6742517865'
  });
  const [toastMessage, setToastMessage] = useState(null);

  const showToast = (msg) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 3500);
  };

  const authFetch = async (url, options = {}) => {
    const headers = {
      ...(options.headers || {}),
      'Authorization': `Bearer ${token}`
    };
    try {
      const res = await fetch(url, { ...options, headers });
      if (res.status === 401) {
        localStorage.removeItem('lovia_admin_token');
        setToken('');
        showToast('🔒 Session expired. Please log in again.');
      }
      return res;
    } catch (err) {
      throw err;
    }
  };

  const handleLogin = async (e) => {
    if (e) e.preventDefault();
    setIsLoggingIn(true);
    setLoginError('');
    try {
      const res = await fetch(`${API_BASE}/admin/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username: loginUsername, password: loginPassword })
      });
      const data = await res.json();
      if (res.ok && data.success && data.token) {
        localStorage.setItem('lovia_admin_token', data.token);
        setToken(data.token);
        showToast('🎉 Logged in successfully!');
      } else {
        setLoginError(data.error || 'Invalid credentials');
      }
    } catch (err) {
      setLoginError('Cannot connect to server. Please check your network.');
    } finally {
      setIsLoggingIn(false);
    }
  };

  const handleLogout = () => {
    localStorage.removeItem('lovia_admin_token');
    setToken('');
    setCharacters([]);
    showToast('Logged out of Admin Panel.');
  };

  const handleChangePassword = async (e) => {
    if (e) e.preventDefault();
    setIsChangingPwd(true);
    try {
      const res = await authFetch(`${API_BASE}/admin/change-password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ currentPassword: pwdCurrent, newPassword: pwdNew })
      });
      const data = await res.json();
      if (res.ok && data.success) {
        setPwdCurrent('');
        setPwdNew('');
        showToast('✅ Admin password updated successfully!');
      } else {
        showToast(`❌ ${data.error || 'Failed to update password'}`);
      }
    } catch (_) {
      showToast('❌ Password update error');
    } finally {
      setIsChangingPwd(false);
    }
  };

  const fetchCharacters = async () => {
    if (!token) return;
    try {
      const res = await authFetch(`${API_BASE}/admin/characters/list`, { method: 'POST' });
      if (res.ok) {
        const data = await res.json();
        setCharacters(data);
        setServerOnline(true);
      }
    } catch (err) {
      setServerOnline(false);
    } finally {
      setLoading(false);
    }
  };

  const fetchStats = async () => {
    if (!token) return;
    try {
      const res = await authFetch(`${API_BASE}/admin/stats`, { method: 'POST' });
      if (res.ok) {
        const data = await res.json();
        setStats(data);
      }
    } catch (_) {}
  };

  const fetchSettings = async () => {
    if (!token) return;
    try {
      const res = await authFetch(`${API_BASE}/admin/settings/get`, { method: 'POST' });
      if (res.ok) {
        const data = await res.json();
        setSettings(data);
      }
    } catch (_) {}
  };

  useEffect(() => {
    if (token) {
      fetchCharacters();
      fetchStats();
      fetchSettings();
      const interval = setInterval(() => {
        fetchCharacters();
        fetchStats();
      }, 10000);
      return () => clearInterval(interval);
    }
  }, [token]);

  const toggleActive = async (id, currentStatus, name) => {
    try {
      const res = await authFetch(`${API_BASE}/admin/characters/${id}/toggle-active`, {
        method: 'PATCH'
      });
      if (res.ok) {
        const data = await res.json();
        setCharacters(prev => prev.map(c => c.id === id ? { ...c, isActive: data.isActive } : c));
        fetchStats();
        showToast(`✨ ${name} is now ${data.isActive ? 'ONLINE (ACTIVE)' : 'OFFLINE (PAUSED)'}`);
      }
    } catch (err) {
      showToast('❌ Failed to toggle character status');
    }
  };

  const toggleHidden = async (id, currentStatus, name) => {
    try {
      const res = await authFetch(`${API_BASE}/admin/characters/${id}/toggle-hidden`, {
        method: 'PATCH'
      });
      if (res.ok) {
        const data = await res.json();
        setCharacters(prev => prev.map(c => c.id === id ? { ...c, isHidden: data.isHidden } : c));
        fetchStats();
        showToast(`👁️ ${name} is now ${data.isHidden ? 'HIDDEN from Discovery' : 'VISIBLE in Discovery'}`);
      }
    } catch (err) {
      showToast('❌ Failed to toggle visibility');
    }
  };

  const deleteCharacter = async (id, name) => {
    if (!window.confirm(`Are you sure you want to permanently delete "${name}"?`)) return;
    try {
      const res = await authFetch(`${API_BASE}/admin/characters/${id}`, { method: 'DELETE' });
      if (res.ok) {
        setCharacters(prev => prev.filter(c => c.id !== id));
        fetchStats();
        showToast(`🗑️ ${name} deleted successfully`);
      }
    } catch (err) {
      showToast('❌ Failed to delete character');
    }
  };

  const saveCharacter = async (charData) => {
    try {
      const res = await authFetch(`${API_BASE}/admin/characters`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(charData)
      });
      if (res.ok) {
        await fetchCharacters();
        await fetchStats();
        setEditingChar(null);
        setIsCreateOpen(false);
        showToast(`🎉 ${charData.name} saved successfully!`);
      }
    } catch (err) {
      showToast('❌ Failed to save character');
    }
  };

  const saveEngineSettings = async () => {
    try {
      const res = await authFetch(`${API_BASE}/admin/settings`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(settings)
      });
      if (res.ok) {
        setIsSettingsOpen(false);
        showToast('⚙️ Server Engine API keys updated successfully!');
      }
    } catch (err) {
      showToast('❌ Failed to update settings');
    }
  };

  const filteredCharacters = characters.filter(c => {
    const matchesSearch = c.name.toLowerCase().includes(search.toLowerCase()) ||
      (c.tagline && c.tagline.toLowerCase().includes(search.toLowerCase())) ||
      (c.tags && c.tags.some(t => t.toLowerCase().includes(search.toLowerCase())));

    const matchesGender = genderFilter === 'all' || c.gender === genderFilter;

    let matchesStatus = true;
    if (statusFilter === 'active') matchesStatus = c.isActive && !c.isHidden;
    if (statusFilter === 'offline') matchesStatus = !c.isActive;
    if (statusFilter === 'hidden') matchesStatus = c.isHidden;

    return matchesSearch && matchesGender && matchesStatus;
  });

  if (!token) {
    return (
      <div style={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: 'radial-gradient(circle at top, #2C1635 0%, #120D1A 60%, #08060D 100%)',
        padding: '24px',
        fontFamily: "'Inter', sans-serif"
      }}>
        {toastMessage && (
          <div style={{
            position: 'fixed',
            top: 24,
            right: 24,
            backgroundColor: '#1E1724',
            border: '1px solid #FF4B72',
            color: '#FFF',
            padding: '12px 20px',
            borderRadius: '12px',
            boxShadow: '0 8px 30px rgba(0,0,0,0.5)',
            zIndex: 9999,
            fontWeight: 600,
            fontSize: '14px'
          }}>
            {toastMessage}
          </div>
        )}

        <div style={{
          backgroundColor: '#1A1424',
          border: '1px solid rgba(255, 75, 114, 0.25)',
          borderRadius: '24px',
          padding: '40px',
          width: '100%',
          maxWidth: '430px',
          boxShadow: '0 25px 60px rgba(0,0,0,0.7)',
          textAlign: 'center'
        }}>
          <div style={{
            width: 68,
            height: 68,
            borderRadius: '20px',
            background: 'linear-gradient(135deg, #FF4B72 0%, #7952FF 100%)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: '32px',
            margin: '0 auto 20px',
            boxShadow: '0 8px 24px rgba(255, 75, 114, 0.4)'
          }}>
            🔐
          </div>

          <h1 style={{ fontSize: '22px', fontWeight: 800, color: '#FFF', marginBottom: '8px', letterSpacing: '-0.3px' }}>
            Lovia Admin Studio
          </h1>
          <p style={{ fontSize: '13px', color: 'rgba(255,255,255,0.6)', marginBottom: '28px', lineHeight: 1.5 }}>
            Sign in with administrative credentials to manage characters, behavioral prompts, and engine keys.
          </p>

          {loginError && (
            <div style={{
              backgroundColor: 'rgba(239, 68, 68, 0.15)',
              border: '1px solid rgba(239, 68, 68, 0.35)',
              color: '#F87171',
              padding: '12px 16px',
              borderRadius: '10px',
              fontSize: '13px',
              marginBottom: '20px',
              textAlign: 'left',
              fontWeight: 600
            }}>
              ⚠️ {loginError}
            </div>
          )}

          <form onSubmit={handleLogin} style={{ display: 'flex', flexDirection: 'column', gap: '18px', textAlign: 'left' }}>
            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#BBB', marginBottom: '6px' }}>
                Admin Username
              </label>
              <input
                type="text"
                value={loginUsername}
                onChange={(e) => setLoginUsername(e.target.value)}
                required
                style={{
                  width: '100%',
                  padding: '12px 14px',
                  backgroundColor: 'rgba(255,255,255,0.06)',
                  border: '1px solid rgba(255,255,255,0.12)',
                  borderRadius: '10px',
                  color: '#FFF',
                  fontSize: '14px',
                  outline: 'none',
                  boxSizing: 'border-box'
                }}
              />
            </div>

            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#BBB', marginBottom: '6px' }}>
                Admin Password
              </label>
              <input
                type="password"
                value={loginPassword}
                onChange={(e) => setLoginPassword(e.target.value)}
                required
                placeholder="••••••••••••"
                style={{
                  width: '100%',
                  padding: '12px 14px',
                  backgroundColor: 'rgba(255,255,255,0.06)',
                  border: '1px solid rgba(255,255,255,0.12)',
                  borderRadius: '10px',
                  color: '#FFF',
                  fontSize: '14px',
                  outline: 'none',
                  boxSizing: 'border-box'
                }}
              />
            </div>

            <button
              type="submit"
              disabled={isLoggingIn}
              style={{
                marginTop: '10px',
                padding: '13px',
                background: 'linear-gradient(135deg, #FF4B72 0%, #7952FF 100%)',
                color: '#FFF',
                border: 'none',
                borderRadius: '10px',
                fontSize: '14px',
                fontWeight: 700,
                cursor: isLoggingIn ? 'not-allowed' : 'pointer',
                boxShadow: '0 4px 18px rgba(255, 75, 114, 0.4)',
                opacity: isLoggingIn ? 0.7 : 1,
                transition: 'opacity 0.2s'
              }}
            >
              {isLoggingIn ? 'Authenticating...' : 'Sign In to Dashboard →'}
            </button>
          </form>
        </div>
      </div>
    );
  }

  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      {/* Toast Notification */}
      {toastMessage && (
        <div style={{
          position: 'fixed',
          top: 24,
          right: 24,
          backgroundColor: '#1E1724',
          border: '1px solid #FF4B72',
          color: '#FFF',
          padding: '12px 20px',
          borderRadius: '12px',
          boxShadow: '0 8px 30px rgba(0,0,0,0.5)',
          zIndex: 9999,
          fontWeight: 600,
          fontSize: '14px',
          animation: 'fadeIn 0.2s ease-in'
        }}>
          {toastMessage}
        </div>
      )}

      {/* Top Navbar */}
      <header style={{
        backgroundColor: 'var(--bg-secondary)',
        borderBottom: '1px solid var(--border-subtle)',
        padding: '16px 32px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        position: 'sticky',
        top: 0,
        zIndex: 100
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
          <div style={{
            width: 40,
            height: 40,
            borderRadius: 12,
            background: 'linear-gradient(135deg, #FF4B72 0%, #7952FF 100%)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: 20,
            boxShadow: '0 4px 15px rgba(255, 75, 114, 0.4)'
          }}>
            💖
          </div>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <h1 style={{ fontSize: '18px', fontWeight: 800, letterSpacing: '-0.3px' }}>Lovia AI Studio</h1>
              <span style={{
                fontSize: '11px',
                padding: '2px 8px',
                borderRadius: '6px',
                backgroundColor: serverOnline ? 'rgba(16, 185, 129, 0.15)' : 'rgba(239, 68, 68, 0.15)',
                color: serverOnline ? '#10B981' : '#EF4444',
                border: `1px solid ${serverOnline ? 'rgba(16, 185, 129, 0.3)' : 'rgba(239, 68, 68, 0.3)'}`,
                fontWeight: 600
              }}>
                {serverOnline ? '● Live Server' : '○ Offline Server'}
              </span>
            </div>
            <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Universal AI Characters & Behavior Control Panel</p>
          </div>
        </div>

        <div style={{ display: 'flex', gap: '12px' }}>
          <button
            onClick={() => setIsSettingsOpen(true)}
            style={{
              padding: '9px 16px',
              backgroundColor: 'rgba(255, 255, 255, 0.06)',
              color: '#FFF',
              borderRadius: '10px',
              border: '1px solid var(--border-subtle)',
              fontSize: '13px',
              fontWeight: 600,
              display: 'flex',
              alignItems: 'center',
              gap: '6px'
            }}
          >
            ⚙️ Server Keys & Security
          </button>

          <button
            onClick={handleLogout}
            style={{
              padding: '9px 16px',
              backgroundColor: 'rgba(239, 68, 68, 0.12)',
              color: '#F87171',
              borderRadius: '10px',
              border: '1px solid rgba(239, 68, 68, 0.3)',
              fontSize: '13px',
              fontWeight: 600,
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              cursor: 'pointer'
            }}
          >
            🔒 Sign Out
          </button>

          {currentNavTab === 'characters' && (
            <button
              onClick={() => setIsCreateOpen(true)}
              style={{
                padding: '9px 20px',
                background: 'linear-gradient(135deg, #FF4B72 0%, #E03E62 100%)',
                color: '#FFF',
                borderRadius: '10px',
                fontSize: '13px',
                fontWeight: 700,
                boxShadow: '0 4px 15px rgba(255, 75, 114, 0.35)',
                display: 'flex',
                alignItems: 'center',
                gap: '8px'
              }}
            >
              + Create AI Agent
            </button>
          )}
        </div>
      </header>

      {/* Navigation Sub-Header Bar */}
      <nav style={{
        backgroundColor: 'rgba(23, 19, 34, 0.7)',
        backdropFilter: 'blur(10px)',
        borderBottom: '1px solid var(--border-subtle)',
        padding: '0 32px',
        display: 'flex',
        gap: '8px',
        position: 'sticky',
        top: 73,
        zIndex: 90,
        marginBottom: '20px'
      }}>
        <button
          onClick={() => setCurrentNavTab('characters')}
          style={{
            padding: '14px 20px',
            background: 'none',
            border: 'none',
            borderBottom: currentNavTab === 'characters' ? '3px solid #FF4B72' : '3px solid transparent',
            color: currentNavTab === 'characters' ? '#FFF' : 'var(--text-muted)',
            fontWeight: currentNavTab === 'characters' ? 800 : 600,
            fontSize: '13px',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            cursor: 'pointer'
          }}
        >
          🎭 AI Characters ({stats.total})
        </button>

        <button
          onClick={() => setCurrentNavTab('packages')}
          style={{
            padding: '14px 20px',
            background: 'none',
            border: 'none',
            borderBottom: currentNavTab === 'packages' ? '3px solid #00C9FF' : '3px solid transparent',
            color: currentNavTab === 'packages' ? '#FFF' : 'var(--text-muted)',
            fontWeight: currentNavTab === 'packages' ? 800 : 600,
            fontSize: '13px',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            cursor: 'pointer'
          }}
        >
          💎 Store Packages & VIP Plans
        </button>

        <button
          onClick={() => setCurrentNavTab('legal')}
          style={{
            padding: '14px 20px',
            background: 'none',
            border: 'none',
            borderBottom: currentNavTab === 'legal' ? '3px solid #7952FF' : '3px solid transparent',
            color: currentNavTab === 'legal' ? '#FFF' : 'var(--text-muted)',
            fontWeight: currentNavTab === 'legal' ? 800 : 600,
            fontSize: '13px',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            cursor: 'pointer'
          }}
        >
          📜 Legal Policies (Privacy & Terms)
        </button>
      </nav>

      {/* Main Content */}
      {currentNavTab === 'packages' && (
        <PackagesManager authFetch={authFetch} showToast={showToast} />
      )}

      {currentNavTab === 'legal' && (
        <LegalManager authFetch={authFetch} showToast={showToast} />
      )}

      {currentNavTab === 'characters' && (
        <main style={{ padding: '0 32px 60px', maxWidth: '1440px', width: '100%', margin: '0 auto', flex: 1 }}>
        {/* Metric Cards Row */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '16px', marginBottom: '28px' }}>
          <MetricCard
            title="Total AI Agents"
            value={stats.total}
            icon="👥"
            color="#7952FF"
            subtitle="Configured in database"
          />
          <MetricCard
            title="Online & Active"
            value={stats.active}
            icon="🟢"
            color="#10B981"
            subtitle="Available in mobile feeds"
          />
          <MetricCard
            title="Turned Off (Offline)"
            value={stats.offline}
            icon="⏸️"
            color="#F59E0B"
            subtitle="Deactivated by admin"
          />
          <MetricCard
            title="Hidden in App"
            value={stats.hidden}
            icon="👁️‍🗨️"
            color="#646A84"
            subtitle="Hidden from discovery tabs"
          />
        </div>

        {/* Filter & Search Bar */}
        <div style={{
          backgroundColor: 'var(--bg-secondary)',
          border: '1px solid var(--border-subtle)',
          borderRadius: '14px',
          padding: '16px 20px',
          display: 'flex',
          flexWrap: 'wrap',
          gap: '14px',
          alignItems: 'center',
          justifyContent: 'space-between',
          marginBottom: '24px'
        }}>
          {/* Search Field */}
          <div style={{ position: 'relative', flex: '1', minWidth: '260px' }}>
            <input
              type="text"
              placeholder="Search by character name, archetype, or tags..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              style={{
                width: '100%',
                padding: '10px 16px 10px 38px',
                backgroundColor: 'rgba(255, 255, 255, 0.05)',
                border: '1px solid var(--border-subtle)',
                borderRadius: '10px',
                color: '#FFF',
                fontSize: '13px'
              }}
            />
            <span style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', opacity: 0.5 }}>🔍</span>
          </div>

          {/* Gender Filter */}
          <div style={{ display: 'flex', gap: '6px' }}>
            {['all', 'female', 'male'].map(g => (
              <button
                key={g}
                onClick={() => setGenderFilter(g)}
                style={{
                  padding: '7px 14px',
                  borderRadius: '8px',
                  fontSize: '12px',
                  fontWeight: 600,
                  backgroundColor: genderFilter === g ? 'var(--primary)' : 'rgba(255, 255, 255, 0.05)',
                  color: genderFilter === g ? '#FFF' : 'var(--text-muted)',
                  border: `1px solid ${genderFilter === g ? 'var(--primary)' : 'var(--border-subtle)'}`
                }}
              >
                {g === 'all' ? 'All Genders' : g === 'female' ? '👩 Female' : '👨 Male'}
              </button>
            ))}
          </div>

          {/* Status Filter */}
          <div style={{ display: 'flex', gap: '6px' }}>
            {[
              { id: 'all', label: 'All Status' },
              { id: 'active', label: '🟢 Online' },
              { id: 'offline', label: '⏸️ Offline' },
              { id: 'hidden', label: '👁️ Hidden' }
            ].map(s => (
              <button
                key={s.id}
                onClick={() => setStatusFilter(s.id)}
                style={{
                  padding: '7px 14px',
                  borderRadius: '8px',
                  fontSize: '12px',
                  fontWeight: 600,
                  backgroundColor: statusFilter === s.id ? 'var(--secondary)' : 'rgba(255, 255, 255, 0.05)',
                  color: statusFilter === s.id ? '#FFF' : 'var(--text-muted)',
                  border: `1px solid ${statusFilter === s.id ? 'var(--secondary)' : 'var(--border-subtle)'}`
                }}
              >
                {s.label}
              </button>
            ))}
          </div>
        </div>

        {/* Characters Grid */}
        {loading ? (
          <div style={{ textAlign: 'center', padding: '60px', color: 'var(--text-muted)' }}>
            Loading AI Characters...
          </div>
        ) : filteredCharacters.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '60px', backgroundColor: 'var(--bg-secondary)', borderRadius: '16px', border: '1px solid var(--border-subtle)' }}>
            <p style={{ fontSize: '16px', fontWeight: 600, color: 'var(--text-muted)' }}>No AI Characters matched your filter.</p>
          </div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: '20px' }}>
            {filteredCharacters.map(char => (
              <CharacterCard
                key={char.id}
                char={char}
                onToggleActive={() => toggleActive(char.id, char.isActive, char.name)}
                onToggleHidden={() => toggleHidden(char.id, char.isHidden, char.name)}
                onEdit={() => setEditingChar(char)}
                onDelete={() => deleteCharacter(char.id, char.name)}
                onPlayVoice={handlePlayVoice}
                playingVoiceId={playingVoiceId}
              />
            ))}
          </div>
        )}
      </main>
      )}

      {/* Edit / Create Character Modal */}
      {(editingChar || isCreateOpen) && (
        <CharacterModal
          initialData={editingChar || {
            name: '',
            gender: 'female',
            age: 21,
            occupation: '',
            personality: '',
            tagline: '',
            bio: '',
            primaryMood: 'romantic',
            defaultGreeting: '',
            customSystemPrompt: '',
            voiceName: 'Intimate Romantic Female',
            voiceId: '3YXAuwCx7wB8kSkKCqsu',
            avatarUrl: '/assets/characters/seraphina_vane_romantic/cover.jpg',
            isActive: true,
            isHidden: false
          }}
          isCreate={isCreateOpen}
          onClose={() => {
            setEditingChar(null);
            setIsCreateOpen(false);
          }}
          onSave={saveCharacter}
          onPlayVoice={handlePlayVoice}
          playingVoiceId={playingVoiceId}
        />
      )}

      {/* Engine Settings Modal */}
      {isSettingsOpen && (
        <div style={{
          position: 'fixed',
          inset: 0,
          backgroundColor: 'rgba(0,0,0,0.75)',
          backdropFilter: 'blur(5px)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000,
          padding: '20px'
        }}>
          <div style={{
            backgroundColor: 'var(--bg-secondary)',
            border: '1px solid var(--border-subtle)',
            borderRadius: '18px',
            width: '100%',
            maxWidth: '520px',
            padding: '28px',
            boxShadow: '0 20px 50px rgba(0,0,0,0.6)'
          }}>
            <h2 style={{ fontSize: '18px', fontWeight: 800, marginBottom: '6px' }}>⚙️ Server AI & Voice Engine Settings</h2>
            <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '20px' }}>
              These keys reside safely on your server and power dynamic AI chat and voice synthesis without exposing keys to mobile app users.
            </p>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px', marginBottom: '24px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '6px' }}>Neural LLM API Key (Google Gemini)</label>
                <input
                  type="password"
                  value={settings.aiApiKey || ''}
                  onChange={(e) => setSettings({ ...settings, aiApiKey: e.target.value })}
                  placeholder="AIzaSy..."
                  style={{
                    width: '100%',
                    padding: '10px 14px',
                    backgroundColor: 'rgba(255,255,255,0.05)',
                    border: '1px solid var(--border-subtle)',
                    borderRadius: '8px',
                    color: '#FFF',
                    fontSize: '13px'
                  }}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '6px' }}>Neural Voice Studio API Key</label>
                <input
                  type="password"
                  value={settings.voiceApiKey || ''}
                  onChange={(e) => setSettings({ ...settings, voiceApiKey: e.target.value })}
                  placeholder="sk_..."
                  style={{
                    width: '100%',
                    padding: '10px 14px',
                    backgroundColor: 'rgba(255,255,255,0.05)',
                    border: '1px solid var(--border-subtle)',
                    borderRadius: '8px',
                    color: '#FFF',
                    fontSize: '13px'
                  }}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '6px' }}>
                  🛡️ AI Content Safety & Flirtation Threshold
                </label>
                <select
                  value={settings.safetyThreshold || 'high'}
                  onChange={(e) => setSettings({ ...settings, safetyThreshold: e.target.value })}
                  style={{
                    width: '100%',
                    padding: '10px 14px',
                    backgroundColor: '#1C1D2A',
                    border: '1px solid var(--border-subtle)',
                    borderRadius: '8px',
                    color: '#FFF',
                    fontSize: '13px',
                    outline: 'none',
                    fontWeight: 600
                  }}
                >
                  <option value="medium">Medium — Store Review Mode (Strict, blocks medium & above)</option>
                  <option value="high">High — Spicy Romance Mode (Permissive, blocks only severe harms)</option>
                  <option value="none">None — Unfiltered Adult Mode (Disabled, maximum flirtation freedom)</option>
                </select>
                <p style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '6px', lineHeight: 1.4 }}>
                  {settings.safetyThreshold === 'medium' && '🔒 Recommended during Apple & Google Play review audits to guarantee 100% compliance approval.'}
                  {(settings.safetyThreshold === 'high' || !settings.safetyThreshold) && '🔥 Recommended for live operations. Allows deep flirtatious banter, romantic intimacy, and adult teasing without false positive blocks.'}
                  {settings.safetyThreshold === 'none' && '⚡ Uninhibited adult roleplay. Disables all optional Gemini harm thresholds for maximum flirtatious freedom.'}
                </p>
              </div>

              {/* Mobile App Store & Sharing URLs */}
              <div style={{ borderTop: '1px solid var(--border-subtle)', paddingTop: '16px', marginTop: '6px' }}>
                <h3 style={{ fontSize: '13px', fontWeight: 700, marginBottom: '4px' }}>📱 Mobile Store & Sharing URLs</h3>
                <p style={{ fontSize: '11px', color: 'var(--text-muted)', marginBottom: '12px' }}>
                  URLs shared with mobile users via the in-app "Share Lovia App" button and store redirects.
                </p>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '11px', fontWeight: 700, marginBottom: '4px' }}>Google Play Store URL</label>
                    <input
                      type="text"
                      value={settings.playStoreUrl || ''}
                      onChange={(e) => setSettings({ ...settings, playStoreUrl: e.target.value })}
                      placeholder="https://play.google.com/store/apps/details?id=com.lovia.ai.friend.app.lovia"
                      style={{
                        width: '100%',
                        padding: '9px 12px',
                        backgroundColor: 'rgba(255,255,255,0.05)',
                        border: '1px solid var(--border-subtle)',
                        borderRadius: '8px',
                        color: '#FFF',
                        fontSize: '12px'
                      }}
                    />
                  </div>
                  <div>
                    <label style={{ display: 'block', fontSize: '11px', fontWeight: 700, marginBottom: '4px' }}>Apple App Store URL</label>
                    <input
                      type="text"
                      value={settings.appStoreUrl || ''}
                      onChange={(e) => setSettings({ ...settings, appStoreUrl: e.target.value })}
                      placeholder="https://apps.apple.com/app/id6742517865"
                      style={{
                        width: '100%',
                        padding: '9px 12px',
                        backgroundColor: 'rgba(255,255,255,0.05)',
                        border: '1px solid var(--border-subtle)',
                        borderRadius: '8px',
                        color: '#FFF',
                        fontSize: '12px'
                      }}
                    />
                  </div>
                </div>
              </div>

              {/* Security: Change Admin Password */}
              <div style={{ borderTop: '1px solid var(--border-subtle)', paddingTop: '16px', marginTop: '6px' }}>
                <h3 style={{ fontSize: '13px', fontWeight: 700, marginBottom: '4px' }}>🔐 Admin Password Management</h3>
                <p style={{ fontSize: '11px', color: 'var(--text-muted)', marginBottom: '12px' }}>
                  Update your dashboard login password. Default: <code>LoviaAdmin@2026</code>
                </p>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px', marginBottom: '10px' }}>
                  <input
                    type="password"
                    value={pwdCurrent}
                    onChange={(e) => setPwdCurrent(e.target.value)}
                    placeholder="Current Password"
                    style={{
                      padding: '9px 12px',
                      backgroundColor: 'rgba(255,255,255,0.05)',
                      border: '1px solid var(--border-subtle)',
                      borderRadius: '8px',
                      color: '#FFF',
                      fontSize: '12px',
                      outline: 'none'
                    }}
                  />
                  <input
                    type="password"
                    value={pwdNew}
                    onChange={(e) => setPwdNew(e.target.value)}
                    placeholder="New Password (min 6 chars)"
                    style={{
                      padding: '9px 12px',
                      backgroundColor: 'rgba(255,255,255,0.05)',
                      border: '1px solid var(--border-subtle)',
                      borderRadius: '8px',
                      color: '#FFF',
                      fontSize: '12px',
                      outline: 'none'
                    }}
                  />
                </div>
                <button
                  type="button"
                  onClick={handleChangePassword}
                  disabled={isChangingPwd || !pwdCurrent || !pwdNew}
                  style={{
                    padding: '7px 16px',
                    backgroundColor: 'rgba(255,255,255,0.08)',
                    color: '#FFF',
                    borderRadius: '8px',
                    border: '1px solid var(--border-subtle)',
                    fontSize: '12px',
                    fontWeight: 600,
                    cursor: (!pwdCurrent || !pwdNew) ? 'not-allowed' : 'pointer',
                    opacity: (!pwdCurrent || !pwdNew) ? 0.6 : 1
                  }}
                >
                  {isChangingPwd ? 'Updating...' : 'Update Password'}
                </button>
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px' }}>
              <button
                onClick={() => setIsSettingsOpen(false)}
                style={{
                  padding: '9px 18px',
                  backgroundColor: 'rgba(255,255,255,0.08)',
                  color: '#FFF',
                  borderRadius: '8px',
                  fontSize: '13px',
                  fontWeight: 600
                }}
              >
                Cancel
              </button>
              <button
                onClick={saveEngineSettings}
                style={{
                  padding: '9px 22px',
                  backgroundColor: 'var(--primary)',
                  color: '#FFF',
                  borderRadius: '8px',
                  fontSize: '13px',
                  fontWeight: 700
                }}
              >
                Save Settings
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// ----------------------------------------------------
// Metric Card Component
// ----------------------------------------------------
function MetricCard({ title, value, icon, color, subtitle }) {
  return (
    <div style={{
      backgroundColor: 'var(--bg-secondary)',
      border: '1px solid var(--border-subtle)',
      borderRadius: '16px',
      padding: '20px',
      display: 'flex',
      alignItems: 'center',
      gap: '16px'
    }}>
      <div style={{
        width: 46,
        height: 46,
        borderRadius: '12px',
        backgroundColor: `${color}20`,
        border: `1px solid ${color}40`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontSize: '22px'
      }}>
        {icon}
      </div>
      <div>
        <span style={{ fontSize: '12px', color: 'var(--text-muted)', fontWeight: 600, display: 'block' }}>{title}</span>
        <span style={{ fontSize: '24px', fontWeight: 800, color: '#FFF' }}>{value}</span>
        <span style={{ fontSize: '11px', color: 'var(--text-dim)', display: 'block' }}>{subtitle}</span>
      </div>
    </div>
  );
}

// ----------------------------------------------------
// Character Card Component with Quick Toggles
// ----------------------------------------------------
function CharacterCard({ char, onToggleActive, onToggleHidden, onEdit, onDelete, onPlayVoice, playingVoiceId }) {
  const avatarFallback = char.gender === 'female'
    ? 'assets/characters/seraphina_vane_romantic/cover.jpg'
    : 'assets/characters/liam_vance_romantic/cover.jpg';

  const displayAvatar = char.avatarUrl || avatarFallback;
  const currentVoiceId = char.voiceId || (char.gender === 'male' ? 'uKGPYP2uuyRQv8SeFre0' : '3YXAuwCx7wB8kSkKCqsu');
  const isPlaying = playingVoiceId === currentVoiceId;

  return (
    <div style={{
      backgroundColor: 'var(--bg-card)',
      border: `1px solid ${char.isActive ? 'var(--border-subtle)' : 'rgba(245, 158, 11, 0.3)'}`,
      borderRadius: '18px',
      padding: '18px',
      display: 'flex',
      flexDirection: 'column',
      gap: '14px',
      opacity: char.isActive ? 1 : 0.65,
      transition: 'all 0.2s ease'
    }}>
      {/* Top Header: Avatar & Info */}
      <div style={{ display: 'flex', gap: '14px' }}>
        <div style={{ position: 'relative' }}>
          <img
            src={displayAvatar}
            alt={char.name}
            onError={(e) => { e.target.src = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop'; }}
            style={{
              width: 64,
              height: 64,
              borderRadius: '14px',
              objectFit: 'cover',
              border: `2px solid ${char.isActive ? 'var(--primary)' : 'var(--text-dim)'}`
            }}
          />
          <span style={{
            position: 'absolute',
            bottom: -4,
            right: -4,
            width: 14,
            height: 14,
            borderRadius: '50%',
            backgroundColor: char.isActive ? 'var(--success)' : 'var(--warning)',
            border: '2px solid var(--bg-secondary)'
          }} />
        </div>

        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '8px' }}>
            <h3 style={{ fontSize: '15px', fontWeight: 800, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
              {char.name}
            </h3>
            <span style={{
              fontSize: '10px',
              fontWeight: 700,
              padding: '2px 7px',
              borderRadius: '6px',
              backgroundColor: 'rgba(255, 75, 114, 0.15)',
              color: 'var(--primary)',
              textTransform: 'uppercase'
            }}>
              {char.primaryMood}
            </span>
          </div>

          <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '2px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
            {char.occupation || 'Roleplay Companion'} • {char.gender === 'female' ? 'Female' : 'Male'} ({char.age}y)
          </p>

          <div style={{ display: 'flex', gap: '6px', marginTop: '6px' }}>
            <span style={{
              fontSize: '10px',
              padding: '2px 6px',
              borderRadius: '4px',
              backgroundColor: char.isActive ? 'rgba(16, 185, 129, 0.15)' : 'rgba(245, 158, 11, 0.15)',
              color: char.isActive ? 'var(--success)' : 'var(--warning)',
              fontWeight: 700
            }}>
              {char.isActive ? 'ONLINE' : 'OFFLINE'}
            </span>
            {char.isHidden && (
              <span style={{
                fontSize: '10px',
                padding: '2px 6px',
                borderRadius: '4px',
                backgroundColor: 'rgba(255, 255, 255, 0.08)',
                color: 'var(--text-dim)',
                fontWeight: 700
              }}>
                HIDDEN
              </span>
            )}
          </div>
        </div>
      </div>

      {/* Voice Badge & Preview Audio Button */}
      <div style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '6px 10px',
        backgroundColor: 'rgba(255, 255, 255, 0.04)',
        borderRadius: '8px',
        fontSize: '11px'
      }}>
        <span style={{ color: 'var(--text-muted)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', maxWidth: '190px' }}>
          🎙️ {char.voiceName || 'Curated Voice'}
        </span>
        <button
          onClick={() => onPlayVoice && onPlayVoice(currentVoiceId)}
          title="Play voice preview: 'This is how I will sound while roleplay'"
          style={{
            padding: '3px 8px',
            borderRadius: '6px',
            backgroundColor: isPlaying ? 'var(--primary)' : 'rgba(255, 255, 255, 0.08)',
            color: '#FFF',
            border: 'none',
            fontSize: '10.5px',
            fontWeight: 700,
            cursor: 'pointer'
          }}
        >
          {isPlaying ? '⏹️ Stop' : '🔊 Listen'}
        </button>
      </div>

      {/* Tagline Preview */}
      <div style={{
        backgroundColor: 'rgba(255, 255, 255, 0.03)',
        padding: '10px 12px',
        borderRadius: '10px',
        fontSize: '11.5px',
        color: 'var(--text-muted)',
        fontStyle: 'italic',
        lineHeight: 1.4
      }}>
        "{char.tagline || 'Ready for heartwarming adventures.'}"
      </div>

      {/* Control Actions Row */}
      <div style={{ display: 'flex', gap: '8px', marginTop: 'auto', paddingTop: '8px', borderTop: '1px solid var(--border-subtle)' }}>
        {/* Turn ON / OFF Switch */}
        <button
          onClick={onToggleActive}
          style={{
            flex: 1,
            padding: '7px 10px',
            borderRadius: '8px',
            fontSize: '11.5px',
            fontWeight: 700,
            backgroundColor: char.isActive ? 'rgba(245, 158, 11, 0.15)' : 'rgba(16, 185, 129, 0.15)',
            color: char.isActive ? 'var(--warning)' : 'var(--success)',
            border: `1px solid ${char.isActive ? 'rgba(245, 158, 11, 0.3)' : 'rgba(16, 185, 129, 0.3)'}`
          }}
        >
          {char.isActive ? '⏸️ Turn OFF' : '▶️ Turn ON'}
        </button>

        {/* Hide / Show Switch */}
        <button
          onClick={onToggleHidden}
          style={{
            flex: 1,
            padding: '7px 10px',
            borderRadius: '8px',
            fontSize: '11.5px',
            fontWeight: 700,
            backgroundColor: char.isHidden ? 'rgba(121, 82, 255, 0.15)' : 'rgba(255, 255, 255, 0.06)',
            color: char.isHidden ? 'var(--secondary)' : 'var(--text-muted)',
            border: '1px solid var(--border-subtle)'
          }}
        >
          {char.isHidden ? '👁️ Show' : '🚫 Hide'}
        </button>

        {/* Edit Button */}
        <button
          onClick={onEdit}
          title="Edit Backstory & Traits"
          style={{
            padding: '7px 12px',
            borderRadius: '8px',
            backgroundColor: 'rgba(255, 255, 255, 0.08)',
            color: '#FFF',
            fontSize: '12px',
            fontWeight: 600
          }}
        >
          ✏️
        </button>

        {/* Delete Button */}
        <button
          onClick={onDelete}
          title="Delete Agent"
          style={{
            padding: '7px 12px',
            borderRadius: '8px',
            backgroundColor: 'rgba(239, 68, 68, 0.15)',
            color: 'var(--danger)',
            fontSize: '12px',
            fontWeight: 600
          }}
        >
          🗑️
        </button>
      </div>
    </div>
  );
}

// ----------------------------------------------------
// Character Edit / Create Modal
// ----------------------------------------------------
function CharacterModal({ initialData, isCreate, onClose, onSave, onPlayVoice, playingVoiceId }) {
  const [formData, setFormData] = useState({ ...initialData });

  const handleChange = (field, val) => {
    setFormData(prev => ({ ...prev, [field]: val }));
  };

  const currentVoiceId = formData.voiceId || (formData.gender === 'male' ? 'uKGPYP2uuyRQv8SeFre0' : '3YXAuwCx7wB8kSkKCqsu');
  const isPlaying = playingVoiceId === currentVoiceId;

  const handleSubmit = (e) => {
    e.preventDefault();
    if (!formData.name || !formData.personality) {
      alert("Name and personality traits are required.");
      return;
    }
    const toSave = {
      ...formData,
      voiceId: currentVoiceId,
      voicePreviewUrl: `https://lovia-api.genxappstudio.cloud/assets/voices/${currentVoiceId}.mp3`
    };
    onSave(toSave);
  };

  return (
    <div style={{
      position: 'fixed',
      inset: 0,
      backgroundColor: 'rgba(0,0,0,0.8)',
      backdropFilter: 'blur(6px)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 1000,
      padding: '20px'
    }}>
      <div style={{
        backgroundColor: 'var(--bg-secondary)',
        border: '1px solid var(--border-subtle)',
        borderRadius: '20px',
        width: '100%',
        maxWidth: '680px',
        maxHeight: '90vh',
        display: 'flex',
        flexDirection: 'column',
        boxShadow: '0 25px 60px rgba(0,0,0,0.7)',
        overflow: 'hidden'
      }}>
        {/* Header */}
        <div style={{
          padding: '20px 24px',
          borderBottom: '1px solid var(--border-subtle)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between'
        }}>
          <h2 style={{ fontSize: '18px', fontWeight: 800 }}>
            {isCreate ? '✨ Create Dynamic AI Character' : `✏️ Edit ${formData.name}`}
          </h2>
          <button onClick={onClose} style={{ background: 'none', color: 'var(--text-muted)', fontSize: '20px' }}>✕</button>
        </div>

        {/* Scrollable Form Body */}
        <form onSubmit={handleSubmit} style={{ padding: '24px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '18px' }}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '6px' }}>Character Name *</label>
              <input
                type="text"
                required
                value={formData.name}
                onChange={(e) => handleChange('name', e.target.value)}
                placeholder="e.g. Seraphina Laurent"
                style={{ width: '100%', padding: '9px 12px', backgroundColor: 'rgba(255,255,255,0.05)', border: '1px solid var(--border-subtle)', borderRadius: '8px', color: '#FFF', fontSize: '13px' }}
              />
            </div>

            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '6px' }}>Occupation / Role</label>
              <input
                type="text"
                value={formData.occupation}
                onChange={(e) => handleChange('occupation', e.target.value)}
                placeholder="e.g. Concert Violinist"
                style={{ width: '100%', padding: '9px 12px', backgroundColor: 'rgba(255,255,255,0.05)', border: '1px solid var(--border-subtle)', borderRadius: '8px', color: '#FFF', fontSize: '13px' }}
              />
            </div>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '14px' }}>
            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '6px' }}>Gender</label>
              <select
                value={formData.gender}
                onChange={(e) => handleChange('gender', e.target.value)}
                style={{ width: '100%', padding: '9px 12px', backgroundColor: '#1C1D2A', border: '1px solid var(--border-subtle)', borderRadius: '8px', color: '#FFF', fontSize: '13px' }}
              >
                <option value="female">Female</option>
                <option value="male">Male</option>
              </select>
            </div>

            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '6px' }}>Age</label>
              <input
                type="number"
                value={formData.age}
                onChange={(e) => handleChange('age', e.target.value)}
                style={{ width: '100%', padding: '9px 12px', backgroundColor: 'rgba(255,255,255,0.05)', border: '1px solid var(--border-subtle)', borderRadius: '8px', color: '#FFF', fontSize: '13px' }}
              />
            </div>

            <div>
              <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '6px' }}>Primary Mood</label>
              <select
                value={formData.primaryMood}
                onChange={(e) => handleChange('primaryMood', e.target.value)}
                style={{ width: '100%', padding: '9px 12px', backgroundColor: '#1C1D2A', border: '1px solid var(--border-subtle)', borderRadius: '8px', color: '#FFF', fontSize: '13px' }}
              >
                {['romantic', 'happy', 'flirty', 'caring', 'playful', 'shy', 'confident', 'mysterious'].map(m => (
                  <option key={m} value={m}>{m.toUpperCase()}</option>
                ))}
              </select>
            </div>
          </div>

          <div>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '6px' }}>Tagline Quote (Shown on Cards)</label>
            <input
              type="text"
              value={formData.tagline}
              onChange={(e) => handleChange('tagline', e.target.value)}
              placeholder="e.g. In every garden I paint, your colors are the brightest."
              style={{ width: '100%', padding: '9px 12px', backgroundColor: 'rgba(255,255,255,0.05)', border: '1px solid var(--border-subtle)', borderRadius: '8px', color: '#FFF', fontSize: '13px' }}
            />
          </div>

          <div>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '6px' }}>Personality & Demeanor *</label>
            <input
              type="text"
              required
              value={formData.personality}
              onChange={(e) => handleChange('personality', e.target.value)}
              placeholder="e.g. Tsundere, feisty, blushes easily, fiercely protective"
              style={{ width: '100%', padding: '9px 12px', backgroundColor: 'rgba(255,255,255,0.05)', border: '1px solid var(--border-subtle)', borderRadius: '8px', color: '#FFF', fontSize: '13px' }}
            />
          </div>

          {/* ElevenLabs Voice Selection & Preview */}
          <div style={{
            backgroundColor: 'rgba(255, 255, 255, 0.03)',
            border: '1px solid var(--border-subtle)',
            borderRadius: '12px',
            padding: '14px'
          }}>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '6px' }}>
              🎙️ Assigned ElevenLabs Voice Sound
            </label>
            <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
              <select
                value={currentVoiceId}
                onChange={(e) => {
                  const selected = CURATED_VOICES.find(v => v.voiceId === e.target.value);
                  handleChange('voiceId', e.target.value);
                  if (selected) handleChange('voiceName', selected.name);
                }}
                style={{ flex: 1, padding: '9px 12px', backgroundColor: '#1C1D2A', border: '1px solid var(--border-subtle)', borderRadius: '8px', color: '#FFF', fontSize: '13px' }}
              >
                {CURATED_VOICES
                  .filter(v => !formData.gender || v.gender === formData.gender)
                  .map(v => (
                    <option key={v.voiceId} value={v.voiceId}>{v.name} ({v.gender})</option>
                  ))
                }
              </select>
              <button
                type="button"
                onClick={() => onPlayVoice && onPlayVoice(currentVoiceId)}
                style={{
                  padding: '9px 14px',
                  borderRadius: '8px',
                  backgroundColor: isPlaying ? 'var(--primary)' : 'rgba(255, 255, 255, 0.08)',
                  color: '#FFF',
                  border: '1px solid var(--border-subtle)',
                  fontSize: '12px',
                  fontWeight: 700,
                  cursor: 'pointer'
                }}
              >
                {isPlaying ? '⏹️ Stop' : '▶️ Play Sample'}
              </button>
            </div>
            <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '6px', fontStyle: 'italic' }}>
              Direct audio sample: "This is how I will sound while roleplay"
            </div>
          </div>

          <div>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '6px' }}>AI Behavioral Directive (The Brain Prompt)</label>
            <textarea
              rows={3}
              value={formData.customSystemPrompt}
              onChange={(e) => handleChange('customSystemPrompt', e.target.value)}
              placeholder="Provide exact instructions on how the AI should react, speak, and emote..."
              style={{ width: '100%', padding: '9px 12px', backgroundColor: 'rgba(255,255,255,0.05)', border: '1px solid var(--border-subtle)', borderRadius: '8px', color: '#FFF', fontSize: '13px', resize: 'vertical' }}
            />
          </div>

          <div>
            <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, marginBottom: '6px' }}>Initial Starter Greeting</label>
            <textarea
              rows={2}
              value={formData.defaultGreeting}
              onChange={(e) => handleChange('defaultGreeting', e.target.value)}
              placeholder="*looks up with a blush* 'You are finally here...'"
              style={{ width: '100%', padding: '9px 12px', backgroundColor: 'rgba(255,255,255,0.05)', border: '1px solid var(--border-subtle)', borderRadius: '8px', color: '#FFF', fontSize: '13px', resize: 'vertical' }}
            />
          </div>

          {/* Quick Toggles */}
          <div style={{ display: 'flex', gap: '20px', padding: '14px', backgroundColor: 'rgba(255,255,255,0.04)', borderRadius: '12px' }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '13px', fontWeight: 600, cursor: 'pointer' }}>
              <input
                type="checkbox"
                checked={formData.isActive}
                onChange={(e) => handleChange('isActive', e.target.checked)}
                style={{ width: 16, height: 16, accentColor: 'var(--primary)' }}
              />
              Turn Agent Online (Active)
            </label>

            <label style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '13px', fontWeight: 600, cursor: 'pointer' }}>
              <input
                type="checkbox"
                checked={formData.isHidden}
                onChange={(e) => handleChange('isHidden', e.target.checked)}
                style={{ width: 16, height: 16, accentColor: 'var(--secondary)' }}
              />
              Hide Agent from Discovery
            </label>
          </div>

          {/* Footer Buttons */}
          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px', marginTop: '10px' }}>
            <button
              type="button"
              onClick={onClose}
              style={{ padding: '10px 20px', backgroundColor: 'rgba(255,255,255,0.08)', color: '#FFF', borderRadius: '8px', fontSize: '13px', fontWeight: 600 }}
            >
              Cancel
            </button>
            <button
              type="submit"
              style={{ padding: '10px 26px', background: 'linear-gradient(135deg, #FF4B72 0%, #E03E62 100%)', color: '#FFF', borderRadius: '8px', fontSize: '13px', fontWeight: 700, boxShadow: '0 4px 15px rgba(255,75,114,0.4)' }}
            >
              {isCreate ? 'Create AI Agent' : 'Save Changes'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
