import sharp from 'sharp';

const WIDTH = 1200;
const HEIGHT = 630;

const svg = `
<svg width="${WIDTH}" height="${HEIGHT}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#0D1117"/>
      <stop offset="50%" stop-color="#161B22"/>
      <stop offset="100%" stop-color="#0D1117"/>
    </linearGradient>
    <linearGradient id="accent" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0%" stop-color="#22C55E"/>
      <stop offset="100%" stop-color="#3B82F6"/>
    </linearGradient>
    <radialGradient id="glow" cx="50%" cy="40%" r="50%">
      <stop offset="0%" stop-color="#22C55E" stop-opacity="0.12"/>
      <stop offset="100%" stop-color="#22C55E" stop-opacity="0"/>
    </radialGradient>
  </defs>

  <!-- Background -->
  <rect width="${WIDTH}" height="${HEIGHT}" fill="url(#bg)"/>

  <!-- Glow -->
  <rect width="${WIDTH}" height="${HEIGHT}" fill="url(#glow)"/>

  <!-- Decorative dots -->
  <circle cx="100" cy="100" r="2" fill="#22C55E" opacity="0.3"/>
  <circle cx="1100" cy="150" r="3" fill="#3B82F6" opacity="0.3"/>
  <circle cx="200" cy="500" r="2" fill="#3B82F6" opacity="0.2"/>
  <circle cx="1050" cy="480" r="2" fill="#22C55E" opacity="0.2"/>
  <circle cx="600" cy="80" r="1.5" fill="#F97316" opacity="0.25"/>

  <!-- Logo mark -->
  <rect x="60" y="55" width="48" height="48" rx="14" fill="url(#accent)"/>
  <text x="84" y="86" font-family="system-ui, sans-serif" font-size="22" font-weight="800" fill="white" text-anchor="middle">LW</text>

  <!-- Tagline -->
  <text x="60" y="130" font-family="system-ui, sans-serif" font-size="18" fill="#8B949E">
    Track Your
  </text>

  <!-- Main headline -->
  <text x="60" y="190" font-family="system-ui, sans-serif" font-size="56" font-weight="800" fill="#F0F6FC">
    Paluwagan Savings,
  </text>
  <text x="60" y="260" font-family="system-ui, sans-serif" font-size="56" font-weight="800" fill="url(#accent)">
    Loans &amp; Returns
  </text>

  <!-- Description -->
  <text x="60" y="330" font-family="system-ui, sans-serif" font-size="22" fill="#8B949E">
    A family-circle sinking fund app for group savings,
  </text>
  <text x="60" y="365" font-family="system-ui, sans-serif" font-size="22" fill="#8B949E">
    loans, and returns tracking.
  </text>

  <!-- Bottom bar -->
  <rect x="60" y="540" width="2" height="40" fill="#22C55E"/>

  <!-- Features -->
  <text x="80" y="558" font-family="system-ui, sans-serif" font-size="16" fill="#22C55E">
    Contribution Tracking
  </text>
  <text x="310" y="558" font-family="system-ui, sans-serif" font-size="16" fill="#3B82F6">
    Loan Management
  </text>
  <text x="540" y="558" font-family="system-ui, sans-serif" font-size="16" fill="#F97316">
    Year-End Returns
  </text>

  <!-- Right decorative element -->
  <rect x="900" y="160" width="240" height="310" rx="24" fill="none" stroke="#22C55E" stroke-width="1" opacity="0.15"/>
  <rect x="940" y="200" width="160" height="8" rx="4" fill="#22C55E" opacity="0.3"/>
  <rect x="940" y="220" width="120" height="8" rx="4" fill="#3B82F6" opacity="0.2"/>
  <rect x="940" y="240" width="140" height="8" rx="4" fill="#F97316" opacity="0.2"/>
  <rect x="940" y="280" width="160" height="120" rx="8" fill="#22C55E" opacity="0.08"/>
  <rect x="940" y="300" width="80" height="6" rx="3" fill="#22C55E" opacity="0.2"/>
  <rect x="940" y="320" width="130" height="60" rx="4" fill="#22C55E" opacity="0.06"/>
  <text x="940" y="460" font-family="system-ui, sans-serif" font-size="13" fill="#8B949E" opacity="0.5">
    lmsystemm.web.app
  </text>
</svg>
`;

async function generate() {
  await sharp(Buffer.from(svg))
    .resize(WIDTH, HEIGHT)
    .png()
    .toFile('public/icons/og-image.png');

  console.log('OG image generated: public/icons/og-image.png');
}

generate().catch(console.error);
