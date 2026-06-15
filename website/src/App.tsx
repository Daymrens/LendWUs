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
import MemberChangelog from './pages/member/Changelog';
import MemberPrivacySecurity from './pages/member/PrivacySecurity';
import MemberBalances from './pages/member/MemberBalances';
import ComplianceReportsPage from './pages/admin/ComplianceReports';
import MemberUnrecognized from './pages/member/Unrecognized';
import TreasurerDashboard from './pages/treasurer/Dashboard';
import TreasurerConfirmations from './pages/treasurer/Dashboard';
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
  Search,
  ChevronDown,
  Star,
  MessageCircle
} from 'lucide-react';
import { useWebNotifications } from './hooks/useWebNotifications';
import { useScrollReveal } from './hooks/useScrollReveal';
import { useCountUp } from './hooks/useCountUp';

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
  const [showScrollTop, setShowScrollTop] = useState(false);
  const [apkUrl, setApkUrl] = useState('https://www.mediafire.com/file/aawu2bcxuz6r6rn/LendWUs_v5.1.apk/file');
  const [apkVersion, setApkVersion] = useState('v5.1');
  const [contactEmail, setContactEmail] = useState('daymren@gmail.com');
  const [contactPhone, setContactPhone] = useState('+63 991 718 5691');
  const featuresRef = React.useRef<HTMLElement>(null);
  const year = new Date().getFullYear();
  const [mockupScreen, setMockupScreen] = useState(0);
  const [openFaq, setOpenFaq] = useState<number | null>(null);
  const [statsVisible, setStatsVisible] = useState(false);
  const statsRef = React.useRef<HTMLDivElement>(null);
  const [pageLoaded, setPageLoaded] = useState(false);
  const [activeSection, setActiveSection] = useState('');
  const [scrollProgress, setScrollProgress] = useState(0);
  const [scrollY, setScrollY] = useState(0);

  useEffect(() => { setPageLoaded(true); }, []);

  useEffect(() => {
    const sections = ['features', 'preview', 'how-it-works', 'download'];
    const observers = sections.map(id => {
      const el = document.getElementById(id);
      if (!el) return null;
      const obs = new IntersectionObserver(
        ([entry]) => { if (entry.isIntersecting) setActiveSection(id); },
        { threshold: 0.3, rootMargin: '-60px 0px 0px 0px' }
      );
      obs.observe(el);
      return obs;
    });
    return () => observers.forEach(o => o?.disconnect());
  }, []);

  const handleRipple: React.MouseEventHandler<HTMLButtonElement> = (e) => {
    const btn = e.currentTarget;
    const ripple = document.createElement('span');
    const rect = btn.getBoundingClientRect();
    const size = Math.max(rect.width, rect.height);
    ripple.style.cssText = `width:${size}px;height:${size}px;left:${e.clientX - rect.left - size / 2}px;top:${e.clientY - rect.top - size / 2}px`;
    ripple.className = 'btn-ripple';
    btn.appendChild(ripple);
    ripple.addEventListener('animationend', () => ripple.remove());
  };

  useEffect(() => {
    const interval = setInterval(() => {
      setMockupScreen(prev => (prev + 1) % 3);
    }, 4000);
    return () => clearInterval(interval);
  }, []);

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

    const handleScroll = () => {
      const max = document.documentElement.scrollHeight - window.innerHeight;
      setScrollProgress(max > 0 ? (window.scrollY / max) * 100 : 0);
      setScrollY(window.scrollY);
      setShowScrollTop(window.scrollY > 500);
    };
    window.addEventListener('scroll', handleScroll, { passive: true });
    handleScroll();
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  useEffect(() => {
    const el = statsRef.current;
    if (!el) return;
    const obs = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) { setStatsVisible(true); obs.unobserve(el); } },
      { threshold: 0.4 }
    );
    obs.observe(el);
    return () => obs.disconnect();
  }, []);

  const { ref: featuresReveal, visible: featuresVisible } = useScrollReveal();
  const { ref: previewsReveal, visible: previewsVisible } = useScrollReveal();
  const { ref: howReveal, visible: howVisible } = useScrollReveal();
  const { ref: downloadReveal, visible: downloadVisible } = useScrollReveal();

  const countTransparency = useCountUp(100, 2000, statsVisible);
  const countFees = useCountUp(0, 1500, statsVisible);

  const faqItems = [
    { q: 'What is a sinking fund / paluwagan?', a: 'A group savings pool where members contribute regularly (per head). Members can borrow from the pool with interest. At year-end, all earned interest is distributed back to members proportionally by head count.' },
    { q: 'How do I join an existing fund?', a: 'Download the mobile app, sign up with email or Google, and enter the group invite code provided by your admin. You\'ll be linked to your fund group immediately.' },
    { q: 'How are loans processed?', a: 'Members submit loan requests through the app. The admin reviews eligibility (sufficient fund balance, no existing unpaid loan, active member) and approves or rejects. Interest is simple, set by the admin.' },
    { q: 'Can I make partial loan repayments?', a: 'Yes. Partial repayments are allowed. The remaining balance stays open until fully repaid. Overpayments are credited as advance credit on your account.' },
    { q: 'How do year-end returns work?', a: 'All interest earned from loans throughout the year is pooled. At year-end, it\'s divided by total active heads and distributed per member based on their head count.' },
    { q: 'Is my data secure?', a: 'Yes. All data is stored in Firebase Cloud Firestore with authenticated access only. Receipt uploads are encrypted. Your financial information is never shared outside your fund group.' },
  ];

  const testimonials = [
    { name: 'Maria Santos', role: 'Member, 2 heads', quote: 'No more messy spreadsheets! I can see my contribution status, loan balance, and returns all in one place.', avatar: 'MS' },
    { name: 'Juan Dela Cruz', role: 'Fund Admin', quote: 'Approving loans and tracking payments used to take hours. Now it\'s done in seconds. The batch operations are game-changing.', avatar: 'JD' },
    { name: 'Elena Rodriguez', role: 'Member, 3 heads', quote: 'The partial repayment feature saved me. I could pay what I could when I could, and the app tracked everything perfectly.', avatar: 'ER' },
  ];

  const handleDownload = async () => {
    try {
      await updateDoc(doc(db, 'app_settings', 'fund_settings'), { downloadCount: increment(1) });
    } catch {}
    window.open(apkUrl, '_blank');
  };

  const smoothScrollTo = (targetY: number) => {
    const start = window.scrollY;
    const diff = targetY - start;
    const duration = Math.min(Math.abs(diff) * 0.5, 800);
    const startTime = performance.now();
    const tick = (now: number) => {
      const elapsed = now - startTime;
      const t = Math.min(elapsed / duration, 1);
      const ease = 1 - Math.pow(1 - t, 3);
      window.scrollTo(0, start + diff * ease);
      if (t < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  };

  const scrollToFeatures = () => {
    if (featuresRef.current) smoothScrollTo(featuresRef.current.offsetTop - 80);
  };

  const scrollToTop = () => {
    smoothScrollTo(0);
  };

  const iconProps = { size: 16, color: '#2ecc71', 'aria-hidden': 'true' as const };

  return (
    <div className={`app${pageLoaded ? ' loaded' : ''}`}>
      <div className="reading-progress" style={{ width: `${scrollProgress}%` }} aria-hidden="true" />
      <nav className="navbar" aria-label="Main navigation">
        <div className="container">
          <a href="/" className="logo">Lend<span>WUs</span></a>
          <div className={`nav-links ${menuOpen ? 'open' : ''}`}>
            <a href="#features" className={activeSection === 'features' ? 'active' : ''} onClick={() => setMenuOpen(false)}>Features</a>
            <a href="#preview" className={activeSection === 'preview' ? 'active' : ''} onClick={() => setMenuOpen(false)}>App Preview</a>
            <a href="#how-it-works" className={activeSection === 'how-it-works' ? 'active' : ''} onClick={() => setMenuOpen(false)}>How it Works</a>
            <a href="#download" className={activeSection === 'download' ? 'active' : ''} onClick={() => setMenuOpen(false)}>Download</a>
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
            {menuOpen ? <X size={24} aria-hidden="true" /> : <Menu size={24} aria-hidden="true" />}
          </button>
        </div>
        {menuOpen && <div className="nav-overlay" onClick={() => setMenuOpen(false)} />}
      </nav>

      <main>
        <header className="hero" id="top" style={{ '--scroll-y': `${scrollY * 0.15}px` } as React.CSSProperties}>
          <div className="container">
            <div className="hero-content">
              <div className="badge">
                <span className="badge-dot" aria-hidden="true" />
                iOS & Android — Now Available
              </div>
              <h1>
                Track Your{' '}
                <span className="highlight-glow">
                  <span className="highlight">Paluwagan</span>
                </span>{' '}
                Savings, Loans &amp; Returns
              </h1>
              <p>
                A modern sinking fund app for your family or group. Track contributions, manage
                loan requests, compute interest, and distribute returns — all in one place.
              </p>
              <div className="hero-btns">
                <button
                  className="btn btn-primary"
                  onClick={(e) => { handleRipple(e); window.location.href = '/login'; }}
                >
                  Open Web App <ArrowRight size={20} aria-hidden="true" className="btn-arrow" />
                </button>
                <button className="btn btn-outline" onClick={(e) => { handleRipple(e); scrollToFeatures(); }}>
                  See How It Works
                </button>
              </div>
              <div className="hero-trust">
                <div className="trust-item"><CheckCircle {...iconProps} /> Secure &amp; Private</div>
                <div className="trust-item"><CheckCircle {...iconProps} /> Real-time Sync</div>
                <div className="trust-item"><CheckCircle {...iconProps} /> No Hidden Fees</div>
              </div>
            </div>
            <div className="hero-visual">
              {/* Floating badges */}
              <div className="phone-float-badge badge-1" aria-hidden="true">
                <span className="float-badge-icon">💰</span>
                <span className="float-badge-value">₱124.5K</span>
                <span className="float-badge-label">Total Fund</span>
              </div>
              <div className="phone-float-badge badge-2" aria-hidden="true">
                <span className="float-badge-icon">👥</span>
                <span className="float-badge-value">12</span>
                <span className="float-badge-label">Members</span>
              </div>
              <div className="phone-float-badge badge-3" aria-hidden="true">
                <span className="float-badge-icon">📈</span>
                <span className="float-badge-value">+₱2.2K</span>
                <span className="float-badge-label">Interest</span>
              </div>

              {/* Phone frame */}
              <div className="phone-mockup" aria-hidden="true">
                <div className="phone-buttons-left" />
                <div className="phone-button-right" />
                <div className="phone-screen">
                  {/* Screen 0: Dashboard */}
                  <div className={`mockup-screen ${mockupScreen === 0 ? 'active' : ''}`}>
                    <div className="app-header">
                      <div className="app-title">Dashboard</div>
                      <div className="user-avatar" />
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
                        <div className="stat-label">Interest Earned</div>
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
                          <div className={`item-icon ${item.type}`} />
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

                  {/* Screen 1: Loans */}
                  <div className={`mockup-screen ${mockupScreen === 1 ? 'active' : ''}`}>
                    <div className="app-header">
                      <div className="app-title">My Loans</div>
                      <div className="user-avatar" />
                    </div>
                    <div className="mockup-loan-card">
                      <div className="mockup-loan-top">
                        <span className="mockup-loan-id">Loan #482A</span>
                        <span className="mockup-loan-status">Active</span>
                      </div>
                      <div className="mockup-loan-balance">₱5,250.00</div>
                      <div className="mockup-loan-label">Remaining Balance</div>
                      <div className="mockup-loan-bar">
                        <div className="mockup-loan-progress" style={{ width: '65%' }} />
                      </div>
                      <div className="mockup-loan-details">
                        <div>
                          <span className="mockup-detail-label">Principal</span>
                          <span className="mockup-detail-value">₱5,000.00</span>
                        </div>
                        <div>
                          <span className="mockup-detail-label">Interest</span>
                          <span className="mockup-detail-value">5%</span>
                        </div>
                        <div>
                          <span className="mockup-detail-label">Due Date</span>
                          <span className="mockup-detail-value">Jul 15, 2026</span>
                        </div>
                      </div>
                      <div className="mockup-btn-primary">Repay Now</div>
                    </div>
                    <div className="preview-section-title" style={{ marginTop: 12 }}>Payment History</div>
                    <div className="app-list">
                      {[
                        { title: 'Payment #1', sub: 'Jun 1, 2026', amount: '₱1,500', type: 'success' },
                        { title: 'Payment #2', sub: 'Jun 15, 2026', amount: '₱1,500', type: 'success' },
                      ].map((item, i) => (
                        <div key={i} className="list-item" style={{ padding: '8px 10px' }}>
                          <div className={`item-icon ${item.type}`} />
                          <div className="item-info">
                            <div className="item-title">{item.title}</div>
                            <div className="item-subtitle">{item.sub}</div>
                          </div>
                          <div className="item-amount text-success">{item.amount}</div>
                        </div>
                      ))}
                    </div>
                  </div>

                  {/* Screen 2: Activity / Notifications */}
                  <div className={`mockup-screen ${mockupScreen === 2 ? 'active' : ''}`}>
                    <div className="app-header">
                      <div className="app-title">Activity</div>
                      <div className="user-avatar" />
                    </div>
                    <div className="mockup-notif-list">
                      {[
                        { icon: '✅', text: 'Loan approved', sub: 'Your loan request was approved', time: '2m ago' },
                        { icon: '💰', text: 'Payment confirmed', sub: '₱500 contribution recorded', time: '1h ago' },
                        { icon: '🔄', text: 'Head count updated', sub: 'Changed to 2 heads', time: '3h ago' },
                        { icon: '📊', text: 'Monthly report ready', sub: 'June 2026 report available', time: '1d ago' },
                        { icon: '⭐', text: 'Interest earned', sub: '₱85.00 added to returns pool', time: '2d ago' },
                      ].map((item, i) => (
                        <div key={i} className="mockup-notif-item">
                          <span className="mockup-notif-icon">{item.icon}</span>
                          <div className="mockup-notif-body">
                            <div className="mockup-notif-title">{item.text}</div>
                            <div className="mockup-notif-sub">{item.sub}</div>
                          </div>
                          <span className="mockup-notif-time">{item.time}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
                <div className="phone-home-indicator" />
              </div>

              {/* Carousel dots */}
              <div className="carousel-dots">
                {[0, 1, 2].map(i => (
                  <button
                    key={i}
                    className={`carousel-dot ${mockupScreen === i ? 'active' : ''}`}
                    onClick={() => setMockupScreen(i)}
                    aria-label={`Screen ${i + 1}`}
                  />
                ))}
              </div>
            </div>
          </div>
        </header>

        <div className="bg-pattern" aria-hidden="true" />
        <div className="bg-gradient-blur" aria-hidden="true" />
        <div ref={featuresReveal} className={`reveal ${featuresVisible ? 'visible' : ''}`}>
          <section id="features" className="features" ref={featuresRef} aria-labelledby="features-title">
            <div className="container">
              <div className="section-header">
                <h2 id="features-title" className="section-title">Everything Your <span className="highlight">Paluwagan</span> Needs</h2>
                <p className="section-subtitle">From member contributions to loan disbursement and year-end returns — no spreadsheets, no confusion.</p>
              </div>
              <div className="feature-grid">
                <div className="feature-card">
                  <div className="feature-icon"><TrendingUp size={22} color="#2ecc71" aria-hidden="true" /></div>
                  <h3>Contribution Tracking</h3>
                  <p>Members submit monthly payments per head with receipt uploads. Admins approve in one tap — every contribution is recorded instantly.</p>
                </div>
                <div className="feature-card">
                  <div className="feature-icon"><SettingsIcon size={22} color="#2ecc71" aria-hidden="true" /></div>
                  <h3>Loan Management</h3>
                  <p>Members request loans; admins set interest rates and due dates. Automated balance tracking with partial repayment support.</p>
                </div>
                <div className="feature-card">
                  <div className="feature-icon"><Zap size={22} color="#2ecc71" aria-hidden="true" /></div>
                  <h3>Fast Onboarding</h3>
                  <p>New members join with a group invite code. No manual data entry — they register, set their heads, and start contributing immediately.</p>
                </div>
                <div className="feature-card">
                  <div className="feature-icon"><ShieldCheck size={22} color="#2ecc71" aria-hidden="true" /></div>
                  <h3>Year-End Returns</h3>
                  <p>Interest earned from loans is distributed back to members per head. The app computes each member's share automatically.</p>
                </div>
              </div>
          </div>
        </section>
        </div>

        <div ref={previewsReveal} className={`reveal ${previewsVisible ? 'visible' : ''}`}>
          <section id="preview" className="previews" aria-labelledby="preview-title">
          <div className="container">
            <div className="section-header">
              <h2 id="preview-title" className="section-title">Built for <span className="highlight">Admins &amp; Members</span></h2>
              <p className="section-subtitle">Two sides of the same app — full control for admins, full transparency for members.</p>
            </div>
            <div className="preview-row">
              <div className="preview-text">
                <div className="preview-badge">Admin Dashboard</div>
                <h2>Full <span className="highlight">Control</span> Over Your Fund</h2>
                <ul className="feature-list">
                  <li><CheckCircle size={18} color="#2ecc71" aria-hidden="true" /> Manage member shares and contribution heads</li>
                  <li><CheckCircle size={18} color="#2ecc71" aria-hidden="true" /> Set interest rates, payment caps, and currency</li>
                  <li><CheckCircle size={18} color="#2ecc71" aria-hidden="true" /> Approve or reject loan and payment requests</li>
                  <li><CheckCircle size={18} color="#2ecc71" aria-hidden="true" /> Export monthly financial reports for the group</li>
                </ul>
              </div>
              <div className="preview-visual">
                <div className="phone-mockup sm-mockup" aria-hidden="true">
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
                <div className="phone-mockup sm-mockup" aria-hidden="true">
                  <div className="phone-screen loan-preview">
                    <div className="app-header">
                      <div className="app-title">My Loans</div>
                    </div>
                    <div className="preview-content">
                      <div className="loan-card-mock">
                        <div className="loan-id">Loan #482A</div>
                        <div className="loan-balance">₱5,250.00</div>
                        <div className="loan-label">Balance Due</div>
                        <div className="loan-bar"><div className="loan-progress" /></div>
                        <div className="repay-btn-mock">Repay Now</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              <div className="preview-text">
                <div className="preview-badge">Member Portal</div>
                <h2>Everything Each <span className="highlight">Member</span> Needs</h2>
                <ul className="feature-list">
                  <li><CheckCircle size={18} color="#2ecc71" aria-hidden="true" /> View outstanding loan balance and repayment status</li>
                  <li><CheckCircle size={18} color="#2ecc71" aria-hidden="true" /> Submit contribution receipts for admin approval</li>
                  <li><CheckCircle size={18} color="#2ecc71" aria-hidden="true" /> Track personal contribution history month by month</li>
                  <li><CheckCircle size={18} color="#2ecc71" aria-hidden="true" /> See your share of year-end interest returns</li>
                </ul>
              </div>
            </div>
          </div>
        </section>
        </div>

        <section className="stats-section" ref={statsRef} aria-label="Key metrics">
          <div className="container">
            <div className="stat-grid">
              <div className="stat-item">
                <div className="stat-number">{countTransparency}%</div>
                <div className="stat-desc">Transparent Tracking</div>
              </div>
              <div className="stat-item">
                <div className="stat-number">Real-time</div>
                <div className="stat-desc">Balance Sync</div>
              </div>
              <div className="stat-item">
                <div className="stat-number">₱{countFees}</div>
                <div className="stat-desc">Hidden Fees</div>
              </div>
            </div>
          </div>
        </section>

        <div ref={howReveal} className={`reveal ${howVisible ? 'visible' : ''}`}>
          <section id="how-it-works" className="how-it-works" aria-labelledby="how-title">
          <div className="container">
            <h2 id="how-title" className="section-title">How It <span className="highlight">Works</span></h2>
            <p className="section-subtitle" style={{ marginBottom: 'var(--space-16)' }}>Three simple steps to get your fund running.</p>
            <div className="steps-flow">
              <div className="step-row">
                <div className="step-visual">
                  <div className="phone-mockup xs-mockup" aria-hidden="true">
                    <div className="phone-buttons-left" />
                    <div className="phone-button-right" />
                    <div className="phone-screen">
                      <div className="app-header">
                        <div className="app-title">Welcome</div>
                      </div>
                      <div className="onboard-content">
                        <div className="onboard-icon">👋</div>
                        <div className="onboard-heading">Join Your Fund</div>
                        <div className="onboard-input"><span className="input-placeholder">Email</span></div>
                        <div className="onboard-input"><span className="input-placeholder">&#9679;&#9679;&#9679;&#9679;&#9679;&#9679;</span></div>
                        <div className="onboard-code-label">Group Code</div>
                        <div className="onboard-code-box">LENDWUS</div>
                        <div className="onboard-btn">Sign Up</div>
                        <div className="onboard-footer">Already a member? Sign In</div>
                      </div>
                    </div>
                    <div className="phone-home-indicator" />
                  </div>
                </div>
                <div className="step-info">
                  <div className="step-badge">Step 1</div>
                  <h3>Join Your Group</h3>
                  <p>New members sign up with email or Google, enter the group invite code <strong>LENDWUS</strong>, and get linked to your fund circle instantly. No manual data entry needed.</p>
                  <ul className="step-checklist">
                    <li><CheckCircle size={14} color="#2ecc71" aria-hidden="true" /> Self-onboarding with group code</li>
                    <li><CheckCircle size={14} color="#2ecc71" aria-hidden="true" /> Email &amp; Google Sign-In</li>
                    <li><CheckCircle size={14} color="#2ecc71" aria-hidden="true" /> Auto-linked to fund group</li>
                  </ul>
                </div>
              </div>

              <div className="step-connector" aria-hidden="true">
                <div className="connector-dot" />
                <div className="connector-line" />
              </div>

              <div className="step-row reverse">
                <div className="step-visual">
                  <div className="phone-mockup xs-mockup" aria-hidden="true">
                    <div className="phone-buttons-left" />
                    <div className="phone-button-right" />
                    <div className="phone-screen">
                      <div className="app-header">
                        <div className="app-title">Contribute</div>
                        <div className="user-avatar" />
                      </div>
                      <div className="contribute-content">
                        <div className="contrib-month">June 2026</div>
                        <div className="contrib-heads">2 Heads · ₱500 required</div>
                        <div className="contrib-progress-row">
                          <div className="contrib-progress-bar">
                            <div className="contrib-progress-fill" style={{ width: '70%' }} />
                          </div>
                          <span className="contrib-progress-text">₱350 / ₱500</span>
                        </div>
                        <div className="contrib-input-row">
                          <span className="contrib-currency">₱</span>
                          <div className="contrib-amount-box">350.00</div>
                        </div>
                        <div className="contrib-receipt-btn">📎 Add Receipt</div>
                        <div className="contrib-submit-btn">Submit Payment</div>
                        <div className="contrib-history-label">Recent Payments</div>
                        <div className="contrib-history-item">
                          <span>May 2026</span><span>₱500</span><span className="contrib-paid">Paid</span>
                        </div>
                        <div className="contrib-history-item">
                          <span>Apr 2026</span><span>₱500</span><span className="contrib-paid">Paid</span>
                        </div>
                      </div>
                    </div>
                    <div className="phone-home-indicator" />
                  </div>
                </div>
                <div className="step-info">
                  <div className="step-badge">Step 2</div>
                  <h3>Contribute &amp; Track</h3>
                  <p>Members submit monthly payments per head with a receipt upload. Admins approve in one tap — every contribution is recorded instantly with full history.</p>
                  <ul className="step-checklist">
                    <li><CheckCircle size={14} color="#2ecc71" aria-hidden="true" /> Receipt upload for each payment</li>
                    <li><CheckCircle size={14} color="#2ecc71" aria-hidden="true" /> Monthly progress tracking</li>
                    <li><CheckCircle size={14} color="#2ecc71" aria-hidden="true" /> Admin approval workflow</li>
                  </ul>
                </div>
              </div>

              <div className="step-connector" aria-hidden="true">
                <div className="connector-dot" />
                <div className="connector-line" />
              </div>

              <div className="step-row">
                <div className="step-visual">
                  <div className="phone-mockup xs-mockup" aria-hidden="true">
                    <div className="phone-buttons-left" />
                    <div className="phone-button-right" />
                    <div className="phone-screen">
                      <div className="app-header">
                        <div className="app-title">Loans</div>
                        <div className="user-avatar" />
                      </div>
                      <div className="loan-content">
                        <div className="loan-available-card">
                          <div className="loan-avail-label">Available to Borrow</div>
                          <div className="loan-avail-amount">₱12,450.00</div>
                        </div>
                        <div className="loan-request-btn">Request a Loan</div>
                        <div className="loan-active-label">Active Loans</div>
                        <div className="loan-active-card">
                          <div className="loan-active-top">
                            <span>Loan #482A</span>
                            <span className="loan-active-badge">Active</span>
                          </div>
                          <div className="loan-active-balance">₱5,250.00</div>
                          <div className="loan-active-bar">
                            <div className="loan-active-progress" style={{ width: '65%' }} />
                          </div>
                          <div className="loan-active-due">Due Jul 15, 2026</div>
                        </div>
                        <div className="loan-interest-note">Interest earned → Year-end returns</div>
                      </div>
                    </div>
                    <div className="phone-home-indicator" />
                  </div>
                </div>
                <div className="step-info">
                  <div className="step-badge">Step 3</div>
                  <h3>Borrow &amp; Earn</h3>
                  <p>Members can request loans from the fund pool with simple interest. All interest paid flows back to everyone as year-end returns based on head count.</p>
                  <ul className="step-checklist">
                    <li><CheckCircle size={14} color="#2ecc71" aria-hidden="true" /> Request loans with simple interest</li>
                    <li><CheckCircle size={14} color="#2ecc71" aria-hidden="true" /> Partial repayments anytime</li>
                    <li><CheckCircle size={14} color="#2ecc71" aria-hidden="true" /> Year-end returns per head share</li>
                  </ul>
                </div>
              </div>
            </div>
          </div>
        </section>
        </div>

        <section id="testimonials" className="testimonials" aria-labelledby="testimonials-title">
          <div className="container">
            <div className="section-header">
              <h2 id="testimonials-title" className="section-title">What <span className="highlight">Members</span> Say</h2>
              <p className="section-subtitle">Real feedback from real fund members.</p>
            </div>
            <div className="testimonials-grid">
              {testimonials.map((t, i) => (
                <div key={i} className="testimonial-card">
                  <div className="testimonial-quote"><MessageCircle size={20} aria-hidden="true" /></div>
                  <p className="testimonial-text">"{t.quote}"</p>
                  <div className="testimonial-author">
                    <div className="testimonial-avatar">{t.avatar}</div>
                    <div>
                      <div className="testimonial-name">{t.name}</div>
                      <div className="testimonial-role">{t.role}</div>
                    </div>
                    <div className="testimonial-stars">{[...Array(5)].map((_, j) => <Star key={j} size={12} fill="#f0c040" color="#f0c040" aria-hidden="true" />)}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section id="faq" className="faq" aria-labelledby="faq-title">
          <div className="container">
            <div className="section-header">
              <h2 id="faq-title" className="section-title">Frequently Asked <span className="highlight">Questions</span></h2>
              <p className="section-subtitle">Everything you need to know about LendWUs.</p>
            </div>
            <div className="faq-list">
              {faqItems.map((item, i) => (
                <div key={i} className={`faq-item ${openFaq === i ? 'open' : ''}`}>
                  <button className="faq-question" onClick={() => setOpenFaq(openFaq === i ? null : i)} aria-expanded={openFaq === i}>
                    <span>{item.q}</span>
                    <ChevronDown size={18} className={`faq-chevron ${openFaq === i ? 'rotated' : ''}`} aria-hidden="true" />
                  </button>
                  <div className="faq-answer">
                    <p>{item.a}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>

        <div ref={downloadReveal} className={`reveal ${downloadVisible ? 'visible' : ''}`}>
        <section id="download" className="download" aria-labelledby="download-title">
          <div className="container">
            <div className="download-box">
              <h2 id="download-title">Ready to Start Your Paluwagan?</h2>
              <p>Access LendWUs from any device. iOS users can add to home screen for a native app-like experience.</p>
              <div className="download-btns">
                <button className="btn btn-primary" onClick={(e) => { handleRipple(e); window.location.href = '/login'; }}>
                  <Smartphone size={20} aria-hidden="true" /> Open Web App <ArrowRight size={16} aria-hidden="true" className="btn-arrow" />
                </button>
                <button className="btn btn-outline" onClick={(e) => { handleRipple(e); handleDownload(); }}>
                  <Download size={20} aria-hidden="true" /> Android APK ({apkVersion})
                </button>
              </div>
              <div className="ios-instructions">
                <p><strong>iOS Users:</strong></p>
                <ol>
                  <li>Open <a href="/login" style={{ color: '#2ecc71' }}>lmsystemm.web.app</a> in Safari</li>
                  <li>Tap the <strong>Share</strong> button <span aria-hidden="true" style={{ fontSize: 18 }}>⎙</span></li>
                  <li>Scroll down and tap <strong>"Add to Home Screen"</strong></li>
                  <li>Tap <strong>"Add"</strong> — LendWUs launches like a native app!</li>
                </ol>
              </div>
              <div className="download-info">Web App • iOS 14+ • Android APK {apkVersion}</div>
            </div>
          </div>
        </section>
        </div>
      </main>

      <footer className="footer">
        <div className="container">
          <div className="footer-top">
            <div className="logo">Lend<span>WUs</span></div>
            <p>Group sinking fund, simplified.</p>
          </div>
          <nav className="footer-links" aria-label="Footer navigation">
            <a href="#features">Features</a>
            <a href="#preview">Preview</a>
            <a href="#testimonials">Testimonials</a>
            <a href="#faq">FAQ</a>
            <a href="#how-it-works">How It Works</a>
            <a href="#download">Download</a>
          </nav>
          <div className="footer-contact">
            <div className="footer-contact-item">
              <span className="footer-contact-icon" aria-hidden="true">📧</span>
              <a href={`mailto:${contactEmail}`}>{contactEmail}</a>
            </div>
            <div className="footer-contact-item">
              <span className="footer-contact-icon" aria-hidden="true">📞</span>
              <span>{contactPhone}</span>
            </div>
          </div>
          <div className="footer-bottom">
            <p>&copy; {year} LendWUs. All rights reserved.</p>
          </div>
        </div>
      </footer>

      {showScrollTop && (
        <button
          className="scroll-top-btn"
          onClick={scrollToTop}
          aria-label="Back to top"
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <polyline points="18 15 12 9 6 15" />
          </svg>
        </button>
      )}
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
    ...(user?.isTreasurer ? [{ path: '/member/treasurer', label: 'Treasurer', icon: '🏦' }] : []),
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
      <Route path="/admin/compliance" element={<ProtectedRoute><AdminLayout><ComplianceReportsPage /></AdminLayout></ProtectedRoute>} />
      <Route path="/admin/data" element={<ProtectedRoute><AdminLayout><DataManagement /></AdminLayout></ProtectedRoute>} />
      <Route path="/admin/notifications" element={<ProtectedRoute><AdminLayout><Notifications /></AdminLayout></ProtectedRoute>} />
      <Route path="/admin/bulk-loans" element={<ProtectedRoute><AdminLayout><BulkLoanProcessing /></AdminLayout></ProtectedRoute>} />
      <Route path="/admin/send-notification" element={<ProtectedRoute><AdminLayout><SendNotification /></AdminLayout></ProtectedRoute>} />
      <Route path="/ios" element={<Navigate to="/login" replace />} />
      <Route path="/member/login" element={<Navigate to="/login" replace />} />
      <Route path="/member/unrecognized" element={<MemberUnrecognized />} />
      <Route path="/maintenance" element={<MaintenanceScreen />} />
      <Route path="/member/dashboard" element={<ProtectedMemberRoute><MemberLayout><MemberDashboard /></MemberLayout></ProtectedMemberRoute>} />
      <Route path="/member/treasurer" element={<ProtectedMemberRoute><MemberLayout><TreasurerDashboard /></MemberLayout></ProtectedMemberRoute>} />
      <Route path="/member/loans" element={<ProtectedMemberRoute><MemberLayout><MemberLoans /></MemberLayout></ProtectedMemberRoute>} />
      <Route path="/member/contributions" element={<ProtectedMemberRoute><MemberLayout><MemberContributions /></MemberLayout></ProtectedMemberRoute>} />
      <Route path="/member/requests" element={<ProtectedMemberRoute><MemberLayout><MemberRequests /></MemberLayout></ProtectedMemberRoute>} />
      <Route path="/member/balances" element={<ProtectedMemberRoute><MemberLayout><MemberBalances /></MemberLayout></ProtectedMemberRoute>} />
      <Route path="/member/profile" element={<ProtectedMemberRoute><MemberLayout><MemberProfilePage /></MemberLayout></ProtectedMemberRoute>} />
      <Route path="/member/notifications" element={<ProtectedMemberRoute><MemberLayout><MemberNotifications /></MemberLayout></ProtectedMemberRoute>} />
       <Route path="/member/edit-profile" element={<Navigate to="/member/profile" replace />} />
      <Route path="/member/help-support" element={<ProtectedMemberRoute><MemberLayout><MemberHelpSupport /></MemberLayout></ProtectedMemberRoute>} />
      <Route path="/member/about" element={<ProtectedMemberRoute><MemberLayout><MemberAbout /></MemberLayout></ProtectedMemberRoute>} />
      <Route path="/member/changelog" element={<ProtectedMemberRoute><MemberLayout><MemberChangelog /></MemberLayout></ProtectedMemberRoute>} />
      <Route path="/member/privacy-security" element={<ProtectedMemberRoute><MemberLayout><MemberPrivacySecurity /></MemberLayout></ProtectedMemberRoute>} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
};

export default App;
