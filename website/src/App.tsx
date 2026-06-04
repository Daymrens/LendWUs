import React, { useState } from 'react';
import './App.css';
import { 
  ArrowRight, 
  Download, 
  ShieldCheck, 
  Settings,
  CheckCircle,
  TrendingUp,
  Smartphone,
  Zap,
  Menu,
  X
} from 'lucide-react';

const App: React.FC = () => {
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <div className="app">
      {/* Navbar */}
      <nav className="navbar">
        <div className="container">
          <div className="logo">Lend<span>WUs</span></div>
          <div className={`nav-links ${menuOpen ? 'open' : ''}`}>
            <a href="#features" onClick={() => setMenuOpen(false)}>Features</a>
            <a href="#preview" onClick={() => setMenuOpen(false)}>App Preview</a>
            <a href="#how-it-works" onClick={() => setMenuOpen(false)}>How it Works</a>
            <button className="btn btn-primary btn-sm" onClick={() => setMenuOpen(false)}>Download</button>
          </div>
          <button className="menu-toggle" onClick={() => setMenuOpen(!menuOpen)} aria-label="Toggle menu">
            {menuOpen ? <X size={24} /> : <Menu size={24} />}
          </button>
        </div>
        {menuOpen && <div className="nav-overlay" onClick={() => setMenuOpen(false)} />}
      </nav>

      {/* Hero Section */}
      <header className="hero">
        <div className="container">
          <div className="hero-content">
            <div className="badge">New: Self-Onboarding v2.0</div>
            <h1>Manage Your Family Circle <span className="highlight">Sinking Fund</span> with Ease</h1>
            <p>Smart lending, automated tracking, and transparent member contributions. All in one place. Built for families, by families.</p>
            <div className="hero-btns">
              <button className="btn btn-primary">
                Get Started <ArrowRight size={20} />
              </button>
              <button className="btn btn-outline">
                Learn More
              </button>
            </div>
            <div className="hero-trust">
              <div className="trust-item"><CheckCircle size={16} /> Secure Firestore</div>
              <div className="trust-item"><CheckCircle size={16} /> Real-time Updates</div>
              <div className="trust-item"><CheckCircle size={16} /> Admin Verified</div>
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

      {/* Features Grid */}
      <section id="features" className="features">
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
              <div className="feature-icon"><Settings color="#2ecc71" /></div>
              <h3>Admin Financial Controls</h3>
              <p>Granular settings for payment caps, interest rates, and global currency selection (PHP, USD, EUR).</p>
            </div>
            <div className="feature-card">
              <div className="feature-icon"><Zap color="#2ecc71" /></div>
              <h3>Instant Onboarding</h3>
              <p>No more manual entry. Members use group code <strong>LENDWUS</strong> to register themselves in seconds.</p>
            </div>
            <div className="feature-card">
              <div className="feature-icon"><ShieldCheck color="#2ecc71" /></div>
              <h3>Verified Transactions</h3>
              <p>Receipt-based contribution workflow. Every peso is accounted for with photographic proof.</p>
            </div>
          </div>
        </div>
      </section>

      {/* Detailed Previews */}
      <section id="preview" className="previews">
        <div className="container">
          {/* Admin Preview */}
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
                      <div className="range-box">Min: ₱150</div>
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

          {/* Member Preview */}
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

      {/* Statistics Section */}
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

      {/* How it Works */}
      <section id="how-it-works" className="how-it-works">
        <div className="container">
          <h2 className="section-title">How it <span className="highlight">Works</span></h2>
          <div className="steps">
            <div className="step">
              <div className="step-num">1</div>
              <h4>Join with Code</h4>
              <p>Enter <strong>LENDWUS</strong> to automatically join the family circle.</p>
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

      {/* Download Section */}
      <section className="download">
        <div className="container">
          <div className="download-box">
            <h2>Ready to grow your fund?</h2>
            <p>Download LendWUs today and start managing your family circle financials professionally.</p>
            <div className="download-btns">
              <button className="btn btn-primary">
                <Download size={20} /> Android APK (v2.1)
              </button>
              <button className="btn btn-outline" disabled>
                <Smartphone size={20} /> iOS (Coming Soon)
              </button>
            </div>
            <div className="download-info">Version 2.1.0 • 24MB • Requires Android 8.0+</div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="footer">
        <div className="container">
          <div className="footer-top">
            <div className="logo">Lend<span>WUs</span></div>
            <p>Empowering Family Circle Financials.</p>
          </div>
          <div className="footer-bottom">
            <p>&copy; 2024 LendWUs App. All rights reserved.</p>
          </div>
        </div>
      </footer>
    </div>
  );
}

export default App;
