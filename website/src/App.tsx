import React, { useState, useEffect } from 'react';
import { Routes, Route, Navigate, useNavigate, useLocation } from 'react-router-dom';
import { doc, getDoc, updateDoc, increment } from 'firebase/firestore';
import { db } from './firebase';
import './App.css';
import { useAuth } from './context/AuthContext';
import Login from './pages/Login';
import MaintenanceScreen from './pages/MaintenanceScreen';
import Dashboard from './pages/admin/Dashboard';
import Members from './pages/admin/Members';
import MemberProfile from './pages/admin/MemberProfile';
import Approvals from './pages/admin/Approvals';
import Settings from './pages/admin/Settings';
import Reports from './pages/admin/Reports';
import DataManagement from './pages/admin/DataManagement';
import Notifications from './pages/admin/Notifications';
import Activity from './pages/admin/Activity';
import GlobalSearch from './pages/admin/GlobalSearch';
import BulkLoanProcessing from './pages/admin/BulkLoanProcessing';
import SendNotification from './pages/admin/SendNotification';
import MemberDashboard from './pages/member/Dashboard';
import MemberContributions from './pages/member/Contributions';
import MemberLoans from './pages/member/Loans';
import MemberRequests from './pages/member/Requests';
import MemberProfilePage from './pages/member/Profile';
import MemberNotifications from './pages/member/Notifications';
import MemberHelpSupport from './pages/member/HelpSupport';
import MemberAbout from './pages/member/About';
import MemberPrivacySecurity from './pages/member/PrivacySecurity';
import MemberUnrecognized from './pages/member/Unrecognized';
import {
  ArrowRight,
  Download,
  ShieldCheck,
  Settings as SettingsIcon,
  CheckCircle,
  TrendingUp,
  Smartphone,
  Zap,
  Menu,
  X,
  Search
} from 'lucide-react';
import { useWebNotifications } from './hooks/useWebNotifications';

const ProtectedRoute: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { user, loading } = useAuth();
  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading...</p></div>;
  if (!user) return <Navigate to="/login" replace />;
  if (user.role !== "admin") return <Navigate to="/member/dashboard" replace />;
  return <>{children}</>;
};

const AdminLayout: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);

  const navItems = [
    { path: '/admin/dashboard', label: 'Dashboard', icon: '📊' },
    { path: '/admin/members', label: 'Members', icon: '👥' },
    { path: '/admin/approvals', label: 'Approvals', icon: '✅' },
    { path: '/admin/activity', label: 'Activity', icon: '📋' },
    { path: '/admin/reports', label: 'Reports', icon: '📈' },
    { path: '/admin/notifications', label: 'Notifications', icon: '🔔' },
    { path: '/admin/bulk-loans', label: 'Bulk Loans', icon: '📤' },
    { path: '/admin/send-notification', label: 'Notify', icon: '📢' },
    { path: '/admin/data', label: 'Data Mgmt', icon: '🗄️' },
    { path: '/admin/settings', label: 'Settings', icon: '⚙️' },
  ];

  const handleNav = (path: string) => {
    navigate(path);
    setSidebarOpen(false);
  };

  return (
    <div className="admin-layout">
      <aside className={`sidebar ${sidebarOpen ? 'open' : ''}`}>
        <div className="sidebar-header">
          <span className="logo-text">Lend<span className="logo-accent">WUs</span></span>
          <span className="sidebar-role">Admin</span>
        </div>
        <nav className="sidebar-nav">
          {navItems.map(item => (
            <button
              key={item.path}
              className={`sidebar-link ${location.pathname === item.path ? 'active' : ''}`}
              onClick={() => handleNav(item.path)}
            >
              <span>{item.icon}</span>
              <span>{item.label}</span>
            </button>
          ))}
        </nav>
        <div className="sidebar-footer">
          <div className="sidebar-user">
            <div className="sidebar-user-email">{user?.email}</div>
          </div>
          <button className="sidebar-logout" onClick={() => { logout(); navigate('/login'); }}>
            Sign Out
          </button>
          <a href="/" className="back-home">← Back to Home</a>
        </div>
      </aside>
      {sidebarOpen && <div className="sidebar-overlay" onClick={() => setSidebarOpen(false)} />}
      <main className="admin-main">
        <NotificationBanner userId={user?.uid} />
        <div className="admin-topbar">
          <button className="menu-toggle" onClick={() => setSidebarOpen(!sidebarOpen)}>
            <Menu size={24} />
          </button>
          <span className="topbar-title">Admin Panel</span>
          <button className="search-toggle" onClick={() => setSearchOpen(true)} title="Search">
            <Search size={20} />
          </button>
        </div>
        {children}
      </main>
      {searchOpen && <GlobalSearch onClose={() => setSearchOpen(false)} />}
    </div>
  );
};

const LandingPage: React.FC = () => {
  const [menuOpen, setMenuOpen] = useState(false);
  const [apkUrl, setApkUrl] = useState('https://www.mediafire.com/file/aawu2bcxuz6r6rn/LendWUs_v5.1.apk/file');
  const [apkVersion, setApkVersion] = useState('v5.1');
  const [contactEmail, setContactEmail] = useState('daymren@gmail.com');
  const [contactPhone, setContactPhone] = useState('+63 991 718 5691');
  const featuresRef = React.useRef<HTMLElement>(null);

  useEffect(() => {
    getDoc(doc(db, 'app_settings', 'fund_settings')).then(snap => {
      if (snap.exists()) {
        const d = snap.data();
        if (d.apkDownloadUrl) setApkUrl(d.apkDownloadUrl);
        if (d.apkVersion) setApkVersion(d.apkVersion);
        if (d.contactEmail) setContactEmail(d.contactEmail);
        if (d.contactPhone) setContactPhone(d.contactPhone);
      }
    }).catch(() => {});
  }, []);

  const handleDownload = async () => {
    try {
      await updateDoc(doc(db, 'app_settings', 'fund_settings'), { downloadCount: increment(1) });
    } catch {}
    window.open(apkUrl, '_blank');
  };

  const scrollToFeatures = () => {
    featuresRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  return (
    <div className="app">
      <nav className="navbar">
        <div className="container">
          <a href="/" className="logo" style={{ textDecoration: 'none' }}>Lend<span>WUs</span></a>
          <div className={`nav-links ${menuOpen ? 'open' : ''}`}>
            <a href="#features" onClick={() => setMenuOpen(false)}>Features</a>
            <a href="#preview" onClick={() => setMenuOpen(false)}>App Preview</a>
            <a href="#how-it-works" onClick={() => setMenuOpen(false)}>How it Works</a>
            <button
              className="btn btn-outline btn-sm"
              onClick={() => window.location.href = '/login'}
              style={{ borderColor: '#22c55e', color: '#22c55e' }}
            >
              Sign In
            </button>
            <button 
              className="btn btn-primary btn-sm" 
              onClick={handleDownload}
            >
              Download
            </button>
          </div>
          <button className="menu-toggle" onClick={() => setMenuOpen(!menuOpen)} aria-label="Toggle menu">
            {menuOpen ? <X size={24} /> : <Menu size={24} />}
          </button>
        </div>
        {menuOpen && <div className="nav-overlay" onClick={() => setMenuOpen(false)} />}
      </nav>

      <header className="hero">
        <div className="container">
          <div className="hero-content">
            <div className="badge">iOS Web App Now Available 🎉</div>
            <h1>Manage Your Group <span className="highlight">Sinking Fund</span> with Ease</h1>
            <p>Smart lending, automated tracking, and transparent member contributions. All in one place. Use on any device — iPhone, iPad, Android, or desktop.</p>
            <div className="hero-btns">
              <button
                className="btn btn-primary"
                onClick={() => window.location.href = '/login'}
              >
                Sign In <ArrowRight size={20} />
              </button>
              <button className="btn btn-outline" onClick={scrollToFeatures}>
                Learn More
              </button>
            </div>
            <div className="hero-trust">
              <div className="trust-item"><CheckCircle size={16} /> Secure Firestore</div>
              <div className="trust-item"><CheckCircle size={16} /> Real-time Updates</div>
              <div className="trust-item"><CheckCircle size={16} /> iOS & Android</div>
            </div>

          </div>
          <div className="hero-visual">
            <div className="phone-mockup">
              <div className="phone-screen dashboard-preview">
                <div className="app-header">
                  <div className="app-title">Dashboard</div>
                  <div className="user-avatar"></div>
                </div>
                <div className="app-stats">
                  <div className="stat-card gradient-1">
                    <div className="stat-label">Total Fund</div>
                    <div className="stat-value">₱124,500.00</div>
                  </div>
                  <div className="stat-card">
                    <div className="stat-label">Active Members</div>
                    <div className="stat-value">12</div>
                  </div>
                  <div className="stat-card">
                    <div className="stat-label">Total Loans</div>
                    <div className="stat-value">₱45,000.00</div>
                  </div>
                  <div className="stat-card">
                    <div className="stat-label">Interest</div>
                    <div className="stat-value">₱2,250.00</div>
                  </div>
                </div>
                <div className="preview-section-title">Recent Activity</div>
                <div className="app-list">
                  {[
                    { title: 'Loan Repayment', sub: 'Approved • Juan', amount: '+₱1,500', type: 'success' },
                    { title: 'New Contribution', sub: 'Pending • Maria', amount: '+₱500', type: 'pending' },
                    { title: 'Loan Issued', sub: 'Active • Pedro', amount: '-₱5,000', type: 'error' }
                  ].map((item, i) => (
                    <div key={i} className="list-item">
                      <div className={`item-icon ${item.type}`}></div>
                      <div className="item-info">
                        <div className="item-title">{item.title}</div>
                        <div className="item-subtitle">{item.sub}</div>
                      </div>
                      <div className={`item-amount ${item.type === 'success' ? 'text-success' : item.type === 'error' ? 'text-error' : 'text-pending'}`}>
                        {item.amount}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>
      </header>

      <section id="features" className="features" ref={featuresRef}>
        <div className="container">
          <div className="section-header">
            <h2 className="section-title">Built for <span className="highlight">Transparency</span></h2>
            <p className="section-subtitle">A complete financial ecosystem for your group, removing the stress of manual bookkeeping.</p>
          </div>
          <div className="feature-grid">
            <div className="feature-card">
              <div className="feature-icon"><TrendingUp color="#2ecc71" /></div>
              <h3>Automated Growth</h3>
              <p>Watch your fund grow with interest-bearing loans. Every repayment adds to the collective pot.</p>
            </div>
            <div className="feature-card">
              <div className="feature-icon"><SettingsIcon color="#2ecc71" /></div>
              <h3>Admin Financial Controls</h3>
              <p>Granular settings for payment caps, interest rates, and global currency selection (PHP, USD, EUR).</p>
            </div>
            <div className="feature-card">
              <div className="feature-icon"><Zap color="#2ecc71" /></div>
              <h3>Instant Onboarding</h3>
              <p>No more manual entry. Members register themselves in seconds with a unique invite code.</p>
            </div>
            <div className="feature-card">
              <div className="feature-icon"><ShieldCheck color="#2ecc71" /></div>
              <h3>Verified Transactions</h3>
              <p>Receipt-based contribution workflow. Every peso is accounted for with photographic proof.</p>
            </div>
          </div>
        </div>
      </section>

      <section id="preview" className="previews">
        <div className="container">
          <div className="preview-row">
            <div className="preview-text">
              <div className="preview-badge">Admin Tools</div>
              <h2>Total <span className="highlight">Control</span> Over Your Fund</h2>
              <ul className="feature-list">
                <li><CheckCircle size={18} color="#2ecc71" /> Manage member shares and contribution heads.</li>
                <li><CheckCircle size={18} color="#2ecc71" /> Set Minimum and Maximum monthly payment limits.</li>
                <li><CheckCircle size={18} color="#2ecc71" /> Real-time Approval workflow for all requests.</li>
                <li><CheckCircle size={18} color="#2ecc71" /> Exportable monthly financial reports.</li>
              </ul>
            </div>
            <div className="preview-visual">
              <div className="phone-mockup sm-mockup">
                <div className="phone-screen settings-preview">
                  <div className="app-header">
                    <div className="app-title">Admin Settings</div>
                  </div>
                  <div className="preview-content">
                    <div className="preview-label">Payment per Head</div>
                    <div className="preview-range">
                      <div className="range-box">Min: ₱500</div>
                      <div className="range-box">Max: ₱1,000</div>
                    </div>
                    <div className="preview-label">Selected Currency</div>
                    <div className="preview-dropdown">PHP (Philippine Peso) ₱</div>
                    <div className="preview-btn-mock">Save Configuration</div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div className="preview-row reverse">
            <div className="preview-visual">
              <div className="phone-mockup sm-mockup">
                <div className="phone-screen loan-preview">
                  <div className="app-header">
                    <div className="app-title">My Loans</div>
                  </div>
                  <div className="preview-content">
                    <div className="loan-card-mock">
                      <div className="loan-id">Loan #482A</div>
                      <div className="loan-balance">₱5,250.00</div>
                      <div className="loan-label">Balance Due</div>
                      <div className="loan-bar"><div className="loan-progress"></div></div>
                      <div className="repay-btn-mock">Repay Now</div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <div className="preview-text">
              <div className="preview-badge">Member Experience</div>
              <h2>Empowering Every <span className="highlight">Member</span></h2>
              <ul className="feature-list">
                <li><CheckCircle size={18} color="#2ecc71" /> Easy-to-read outstanding loan balances.</li>
                <li><CheckCircle size={18} color="#2ecc71" /> One-click repayment requests with QR integration.</li>
                <li><CheckCircle size={18} color="#2ecc71" /> Automated interest calculations based on fund rules.</li>
                <li><CheckCircle size={18} color="#2ecc71" /> Personal contribution history and status tracking.</li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      <section className="stats-section">
        <div className="container">
          <div className="stat-grid">
            <div className="stat-item">
              <div className="stat-number">100%</div>
              <div className="stat-desc">Transparent Tracking</div>
            </div>
            <div className="stat-item">
              <div className="stat-number">0.0</div>
              <div className="stat-desc">Hidden Fees</div>
            </div>
            <div className="stat-item">
              <div className="stat-number">Real-time</div>
              <div className="stat-desc">Balance Sync</div>
            </div>
          </div>
        </div>
      </section>

      <section id="how-it-works" className="how-it-works">
        <div className="container">
          <h2 className="section-title">How it <span className="highlight">Works</span></h2>
          <div className="steps">
            <div className="step">
              <div className="step-num">1</div>
              <h4>Join with Code</h4>
              <p>Enter your unique group code to automatically join.</p>
            </div>
            <div className="step">
              <div className="step-num">2</div>
              <h4>Contribute</h4>
              <p>Pay your monthly heads via GCash and upload the receipt.</p>
            </div>
            <div className="step">
              <div className="step-num">3</div>
              <h4>Grow Fund</h4>
              <p>Earn interest collectively as the fund issues loans to members.</p>
            </div>
          </div>
        </div>
      </section>

      <section className="download">
        <div className="container">
          <div className="download-box">
            <h2>Ready to grow your fund?</h2>
            <p>Access LendWUs on any device. iOS users can add to home screen for an app-like experience.</p>
            <div className="download-btns">
              <button className="btn btn-primary" onClick={() => window.location.href = '/login'}>
                <Smartphone size={20} /> Open iOS Web App
              </button>
              <button className="btn btn-outline" onClick={handleDownload}>
                <Download size={20} /> Android APK ({apkVersion})
              </button>
            </div>
            <div className="ios-instructions">
              <p><strong>📱 iOS Users:</strong></p>
              <ol>
                <li>Open <a href="/login" style={{ color: '#2ecc71' }}>lmsystemm.web.app</a> in Safari</li>
                <li>Tap the <strong>Share</strong> button <span style={{ fontSize: 18 }}>⎙</span></li>
                <li>Scroll down and tap <strong>"Add to Home Screen"</strong></li>
                <li>Tap <strong>"Add"</strong> — LendWUs will appear on your home screen like a native app!</li>
              </ol>
            </div>
            <div className="download-info">Web App • Works on iOS 14+ • Android APK {apkVersion} • 24MB</div>
          </div>
        </div>
      </section>

      <footer className="footer">
        <div className="container">
          <div className="footer-top">
            <div className="logo">Lend<span>WUs</span></div>
            <p>Empowering Group Financials.</p>
          </div>
            <div className="footer-contact">
            <div className="footer-contact-item">
              <span className="footer-contact-icon">📧</span>
              <a href={`mailto:${contactEmail}`}>{contactEmail}</a>
            </div>
            <div className="footer-contact-item">
              <span className="footer-contact-icon">📞</span>
              <span>{contactPhone}</span>
            </div>
          </div>
          <div className="footer-bottom">
            <p>&copy; 2025 LendWUs App. All rights reserved.</p>
          </div>
        </div>
      </footer>
    </div>
  );
};

const ProtectedMemberRoute: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { user, loading, isRecognized } = useAuth();
  const [maintenance, setMaintenance] = useState<{ on: boolean }>({ on: false });

  useEffect(() => {
    getDoc(doc(db, 'app_settings', 'fund_settings')).then(snap => {
      if (snap.exists() && snap.data().isMaintenanceMode === true) {
        setMaintenance({ on: true });
      }
    }).catch(() => {});
  }, []);

  if (loading) return <div className="admin-loading"><div className="spinner" /><p>Loading...</p></div>;
  if (!user) return <Navigate to="/login" replace />;
  if (user.role !== "member") return <Navigate to="/admin/dashboard" replace />;
  if (!isRecognized) return <Navigate to="/member/unrecognized" replace />;
  if (maintenance.on) return <MaintenanceScreen />;
  return <>{children}</>;
};

const MemberLayout: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [sidebarOpen, setSidebarOpen] = useState(false);

  const navItems = [
    { path: '/member/dashboard', label: 'Home', icon: '🏠' },
    { path: '/member/loans', label: 'Loans', icon: '🏦' },
    { path: '/member/contributions', label: 'Contributions', icon: '💰' },
    { path: '/member/requests', label: 'Requests', icon: '📋' },
    { path: '/member/notifications', label: 'Notifications', icon: '🔔' },
    { path: '/member/profile', label: 'Profile', icon: '👤' },
    { path: '/member/privacy-security', label: 'Privacy & Security', icon: '🔒' },
    { path: '/member/help-support', label: 'Help & Support', icon: '❓' },
    { path: '/member/about', label: 'About', icon: 'ℹ️' },
  ];

  const handleNav = (path: string) => {
    navigate(path);
    setSidebarOpen(false);
  };

  return (
    <div className="admin-layout">
      <aside className={`sidebar ${sidebarOpen ? 'open' : ''}`}>
        <div className="sidebar-header">
          <span className="logo-text">Lend<span className="logo-accent">WUs</span></span>
          <span className="sidebar-role">Member</span>
        </div>
        <nav className="sidebar-nav">
          {navItems.map(item => (
            <button
              key={item.path}
              className={`sidebar-link ${location.pathname === item.path ? 'active' : ''}`}
              onClick={() => handleNav(item.path)}
            >
              <span>{item.icon}</span>
              <span>{item.label}</span>
            </button>
          ))}
        </nav>
        <div className="sidebar-footer">
          <div className="sidebar-user">
            <div className="sidebar-user-email">{user?.email}</div>
          </div>
          <button className="sidebar-logout" onClick={() => { logout(); navigate('/login'); }}>
            Sign Out
          </button>
          <a href="/" className="back-home">← Back to Home</a>
        </div>
      </aside>
      {sidebarOpen && <div className="sidebar-overlay" onClick={() => setSidebarOpen(false)} />}
      <main className="admin-main">
        <NotificationBanner userId={user?.uid} />
        <div className="admin-topbar">
          <button className="menu-toggle" onClick={() => setSidebarOpen(!sidebarOpen)}>
            <Menu size={24} />
          </button>
          <span className="topbar-title">Member Portal</span>
        </div>
        {children}
      </main>
    </div>
  );
};

const NotificationBanner: React.FC<{ userId: string | undefined }> = ({ userId }) => {
  const { showPrompt, requestPermission, dismiss } = useWebNotifications(userId);
  if (!showPrompt) return null;
  return (
    <div className="notif-prompt">
      <span>Get notified of new updates and approvals</span>
      <div className="notif-prompt-actions">
        <button className="btn btn-sm btn-primary" onClick={requestPermission}>Allow</button>
        <button className="btn btn-sm btn-outline" onClick={dismiss}>Later</button>
      </div>
    </div>
  );
};

const App: React.FC = () => {
  return (
    <Routes>
      <Route path="/" element={<LandingPage />} />
      <Route path="/login" element={<Login />} />
      <Route path="/admin" element={<Navigate to="/login" replace />} />
      <Route path="/admin/dashboard" element={<ProtectedRoute><AdminLayout><Dashboard /></AdminLayout></ProtectedRoute>} />
      <Route path="/admin/members" element={<ProtectedRoute><AdminLayout><Members /></AdminLayout></ProtectedRoute>} />
      <Route path="/admin/members/:id" element={<ProtectedRoute><AdminLayout><MemberProfile /></AdminLayout></ProtectedRoute>} />
      <Route path="/admin/approvals" element={<ProtectedRoute><AdminLayout><Approvals /></AdminLayout></ProtectedRoute>} />
      <Route path="/admin/activity" element={<ProtectedRoute><AdminLayout><Activity /></AdminLayout></ProtectedRoute>} />
      <Route path="/admin/settings" element={<ProtectedRoute><AdminLayout><Settings /></AdminLayout></ProtectedRoute>} />
      <Route path="/admin/reports" element={<ProtectedRoute><AdminLayout><Reports /></AdminLayout></ProtectedRoute>} />
      <Route path="/admin/data" element={<ProtectedRoute><AdminLayout><DataManagement /></AdminLayout></ProtectedRoute>} />
      <Route path="/admin/notifications" element={<ProtectedRoute><AdminLayout><Notifications /></AdminLayout></ProtectedRoute>} />
      <Route path="/admin/bulk-loans" element={<ProtectedRoute><AdminLayout><BulkLoanProcessing /></AdminLayout></ProtectedRoute>} />
      <Route path="/admin/send-notification" element={<ProtectedRoute><AdminLayout><SendNotification /></AdminLayout></ProtectedRoute>} />
      <Route path="/ios" element={<Navigate to="/login" replace />} />
      <Route path="/member/login" element={<Navigate to="/login" replace />} />
      <Route path="/member/unrecognized" element={<MemberUnrecognized />} />
      <Route path="/maintenance" element={<MaintenanceScreen />} />
      <Route path="/member/dashboard" element={<ProtectedMemberRoute><MemberLayout><MemberDashboard /></MemberLayout></ProtectedMemberRoute>} />
      <Route path="/member/loans" element={<ProtectedMemberRoute><MemberLayout><MemberLoans /></MemberLayout></ProtectedMemberRoute>} />
      <Route path="/member/contributions" element={<ProtectedMemberRoute><MemberLayout><MemberContributions /></MemberLayout></ProtectedMemberRoute>} />
      <Route path="/member/requests" element={<ProtectedMemberRoute><MemberLayout><MemberRequests /></MemberLayout></ProtectedMemberRoute>} />
      <Route path="/member/profile" element={<ProtectedMemberRoute><MemberLayout><MemberProfilePage /></MemberLayout></ProtectedMemberRoute>} />
      <Route path="/member/notifications" element={<ProtectedMemberRoute><MemberLayout><MemberNotifications /></MemberLayout></ProtectedMemberRoute>} />
       <Route path="/member/edit-profile" element={<Navigate to="/member/profile" replace />} />
      <Route path="/member/help-support" element={<ProtectedMemberRoute><MemberLayout><MemberHelpSupport /></MemberLayout></ProtectedMemberRoute>} />
      <Route path="/member/about" element={<ProtectedMemberRoute><MemberLayout><MemberAbout /></MemberLayout></ProtectedMemberRoute>} />
      <Route path="/member/privacy-security" element={<ProtectedMemberRoute><MemberLayout><MemberPrivacySecurity /></MemberLayout></ProtectedMemberRoute>} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
};

export default App;
